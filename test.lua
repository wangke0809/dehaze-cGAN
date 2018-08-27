require 'image'
require 'nn'
require 'nngraph'
require 'torch'
require 'model'
util = paths.dofile('util/util.lua')
torch.setdefaulttensortype('torch.FloatTensor')

opt = {
    DATA_ROOT = './datasets',           -- path to images (should have subfolders 'train', 'val', etc)
    batchSize = 1,            -- # images in batch
    loadSize = 512,           -- scale images to this size
    fineSize = 512,           --  then crop to this size
    fineSize1 = 512,           --  then crop to this size
    flip=0,                   -- horizontal mirroring data augmentation
    display = 1,              -- display samples while training. 0 = false
    display_id = 200,         -- display window id.
    gpu = 1,                  -- gpu = 0 is CPU mode. gpu=X is GPU mode on GPU X
    how_many = 'all',         -- how many test images to run (set to all to run on every image found in the data/phase folder)
    which_direction = 'BtoA', -- AtoB or BtoA
    phase = 'test_syn',            -- train, val, test ,etc
    preprocess = 'regular',   -- for special purpose preprocessing, e.g., for colorization, change this (selects preprocessing functions in util.lua)
    aspect_ratio = 1.0,       -- aspect ratio of result images
    name = 'dehaze',                -- name of experiment, selects which model to run, should generally should be passed on command line
    input_nc = 3,             -- #  of input image channels
    output_nc = 3,            -- #  of output image channels
    serial_batches = 1,       -- if 1, takes images in order to make batches, otherwise takes them randomly
    serial_batch_iter = 1,    -- iter into serial image list
    cudnn = 1,                -- set to 0 to not use cudnn (untested)
    checkpoints_dir = './model', -- loads models from here
    results_dir='./results/',          -- saves results here
    which_epoch = '500',            -- which epoch to test? set to 'latest' to use latest cached model
    output_wide = 640,
    output_high = 480,
}

for k,v in pairs(opt) do opt[k] = tonumber(os.getenv(k)) or os.getenv(k) or opt[k] end
opt.nThreads = 1
print(opt)
if opt.display == 0 then opt.display = false end

opt.manualSeed = torch.random(1, 10000) -- set seed
print("Random Seed: " .. opt.manualSeed)
torch.manualSeed(opt.manualSeed)
torch.setdefaulttensortype('torch.FloatTensor')

opt.netG_name = opt.name .. '/' .. opt.which_epoch .. '_net_G'

local data_loader = paths.dofile('data/data.lua')
print('#threads...' .. opt.nThreads)
local data = data_loader.new(opt.nThreads, opt)
print("Dataset Size: ", data:size())
local idx_A = nil0
local idx_B = nil
local input_nc = opt.input_nc
local output_nc = opt.output_nc
idx_A = {input_nc+1, input_nc+output_nc}
idx_B = {1, input_nc}
local input = torch.FloatTensor(opt.batchSize,3,opt.fineSize,opt.fineSize)
local target = torch.FloatTensor(opt.batchSize,3,opt.fineSize,opt.fineSize)
print('checkpoints_dir', opt.checkpoints_dir)
local netG = util.load(paths.concat(opt.checkpoints_dir, opt.netG_name .. '.t7'), opt)

function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

if opt.how_many=='all' then
    opt.how_many=data:size()
end
opt.how_many=math.min(opt.how_many, data:size())

local filepaths = {} 
for n=1,math.floor(opt.how_many/opt.batchSize) do
    print('processing batch ' .. n)
    
    local data_curr, filepaths_curr = data:getBatch()
    filepaths_curr = util.basename_batch(filepaths_curr)
    print('filepaths_curr: ', filepaths_curr)
    
    input = data_curr[{ {}, idx_A, {}, {} }]
    target = data_curr[{ {}, idx_B, {}, {} }]

    
    if opt.gpu > 0 then
        input = input:cuda()
    end
    print(input:size())    
    if opt.preprocess == 'colorization' then
    else 
        output = util.deprocess_batch(netG:forward(input))
        input = util.deprocess_batch(input):float()
        output = output:float()
        target = util.deprocess_batch(target):float()


    end
    paths.mkdir(paths.concat(opt.results_dir, opt.netG_name .. '_' .. opt.phase))
    local image_dir = paths.concat(opt.results_dir, opt.netG_name .. '_' .. opt.phase)
    paths.mkdir(image_dir)
    paths.mkdir(paths.concat(image_dir,'output'))

    for i=1, opt.batchSize do
        image.save(paths.concat(image_dir,'output',filepaths_curr[i]), image.scale(output[i],output[i]:size(2),output[i]:size(3)/opt.aspect_ratio))
    end
    print('Saved images to: ', image_dir)
    
    
    filepaths = TableConcat(filepaths, filepaths_curr)
end


