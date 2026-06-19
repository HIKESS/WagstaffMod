-- Wagstaff Standalone — Shaders (nearsight blur post-process)
-- 100% Wagstaff. Copied as-is from Hamlet Characters - Rework (workshop 2399658326).
-- blurh.ksh / blurv.ksh are base-game shaders resolved at runtime; only postprocess_blur.ksh ships with the mod.

local PostProcessorEffects = GLOBAL.PostProcessorEffects
local SamplerEffects = GLOBAL.SamplerEffects
local resolvefilepath = GLOBAL.resolvefilepath
local SamplerSizes = GLOBAL.SamplerSizes
local SamplerColourMode = GLOBAL.SamplerColourMode
local SamplerEffectBase = GLOBAL.SamplerEffectBase
local UniformVariables = GLOBAL.UniformVariables

local FILTER_MODE = GLOBAL.FILTER_MODE
local MIP_FILTER_MODE = GLOBAL.MIP_FILTER_MODE


AddModShadersInit(function()
	local PostProcessor = GLOBAL.PostProcessor

    SamplerEffects.WagstaffBlurH = PostProcessor:AddSamplerEffect("shaders/blurh.ksh", SamplerSizes.Relative, 0.5, 0.5, SamplerColourMode.RGB, SamplerEffectBase.PostProcessSampler)
    PostProcessor:SetEffectUniformVariables(SamplerEffects.WagstaffBlurH, UniformVariables.SAMPLER_PARAMS)
    PostProcessor:SetSamplerEffectFilter(SamplerEffects.WagstaffBlurH, FILTER_MODE.LINEAR, FILTER_MODE.LINEAR, MIP_FILTER_MODE.NONE)

    SamplerEffects.WagstaffBlurV = PostProcessor:AddSamplerEffect("shaders/blurv.ksh", SamplerSizes.Relative, 0.5, 0.5, SamplerColourMode.RGB, SamplerEffectBase.Shader, SamplerEffects.WagstaffBlurH)
    PostProcessor:SetEffectUniformVariables(SamplerEffects.WagstaffBlurV, UniformVariables.SAMPLER_PARAMS)
    PostProcessor:SetSamplerEffectFilter(SamplerEffects.WagstaffBlurV, FILTER_MODE.LINEAR, FILTER_MODE.LINEAR, MIP_FILTER_MODE.NONE)
    
	UniformVariables.BLUR_PARAMS = PostProcessor:AddUniformVariable("BLUR_PARAMS", 4)
    PostProcessor:SetUniformVariable(UniformVariables.BLUR_PARAMS, 0.5, 0.5, 0.3, 2.0)

    PostProcessorEffects.WagstaffBlur = PostProcessor:AddPostProcessEffect(resolvefilepath("shaders/postprocess_blur.ksh"))
    PostProcessor:AddSampler(PostProcessorEffects.WagstaffBlur, SamplerEffectBase.Shader, SamplerEffects.WagstaffBlurV)
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.WagstaffBlur, UniformVariables.BLUR_PARAMS)
end)


AddModShadersSortAndEnable(function()
	local PostProcessor = GLOBAL.PostProcessor
    
    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.WagstaffBlur, PostProcessorEffects.Bloom)
    
    local PostProcessor__index = GLOBAL.getmetatable(PostProcessor).__index
    
    function PostProcessor__index:SetBlurEnabled(enabled)
		self:EnablePostProcessEffect(PostProcessorEffects.WagstaffBlur, enabled)
    end
    
    function PostProcessor__index:SetBlurCenter(x, y)
		self:SetUniformVariable(UniformVariables.BLUR_PARAMS, x, y)
    end
    
    function PostProcessor__index:SetBlurParams(start_radius, strength)
		self:SetUniformVariable(UniformVariables.BLUR_PARAMS, nil, nil, start_radius, strength)
    end
end)
