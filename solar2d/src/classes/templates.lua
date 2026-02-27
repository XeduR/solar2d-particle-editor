---------------------------------------------------------------------------------
-- templates.lua - Prebuilt particle effect definitions
---------------------------------------------------------------------------------

local M = {}

local templates = {
    -- Dense upward flame effect. Gravity emitter with orange-to-red gradient,
    -- negative Y gravity for upward motion. Large start size shrinks to embers.
    -- Additive blending for bright, glowing appearance.
    fire = {
        name = "Fire",
        description = "Orange and yellow flames with upward motion",
        params = {
            emitterType = 0,               -- Gravity emitter (particles affected by gravity)
            maxParticles = 300,             -- Dense particle field for realistic flames
            angle = -90,                    -- Emit upward
            angleVariance = 10,             -- Narrow cone for cohesive flame shape
            speed = 60,                     -- Moderate rise speed
            speedVariance = 20,
            sourcePositionVariancex = 7,    -- Tight source spread
            sourcePositionVariancey = 5,
            particleLifespan = 1.5,
            particleLifespanVariance = 0.5,
            startParticleSize = 40,         -- Large initial size, shrinks to embers
            startParticleSizeVariance = 10,
            finishParticleSize = 10,
            finishParticleSizeVariance = 5,
            startColorRed = 1,              -- Bright orange start
            startColorGreen = 0.6,
            startColorBlue = 0.1,
            startColorAlpha = 1,
            startColorVarianceRed = 0.1,
            startColorVarianceGreen = 0.1,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0,
            finishColorRed = 1,             -- Fades to deep red then transparent
            finishColorGreen = 0.15,
            finishColorBlue = 0,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = -80,                 -- Strong upward pull
            blendFuncSource = 770,          -- GL_SRC_ALPHA
            blendFuncDestination = 1,       -- GL_ONE (additive blending)
        },
    },

    -- Billowing smoke with normal blending. Particles grow as they rise,
    -- creating volumetric appearance. Semi-transparent gray fading to invisible.
    smoke = {
        name = "Smoke",
        description = "Gray smoke billowing upward",
        params = {
            emitterType = 0,
            maxParticles = 200,
            angle = -90,
            angleVariance = 15,             -- Wider spread than fire for billowing
            speed = 30,                     -- Slow drift upward
            speedVariance = 10,
            sourcePositionVariancex = 5,
            sourcePositionVariancey = 5,
            particleLifespan = 3,           -- Long life for slow dissipation
            particleLifespanVariance = 1,
            startParticleSize = 40,         -- Large start, grows to huge plumes
            startParticleSizeVariance = 10,
            finishParticleSize = 160,
            finishParticleSizeVariance = 40,
            startColorRed = 0.5,            -- Medium gray
            startColorGreen = 0.5,
            startColorBlue = 0.5,
            startColorAlpha = 0.6,          -- Semi-transparent
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.4,           -- Slightly darker gray, fades out
            finishColorGreen = 0.4,
            finishColorBlue = 0.4,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = -20,                 -- Gentle rise
            blendFuncSource = 770,          -- GL_SRC_ALPHA
            blendFuncDestination = 771,     -- GL_ONE_MINUS_SRC_ALPHA (normal blend)
            textureFileName = "assets/particles/smoke_01.png",
        },
    },

    -- High-speed small particles with gravity pull downward, simulating
    -- sparks from welding or grinding. Short lifespan, yellow to red.
    sparks = {
        name = "Sparks",
        description = "Fast-moving hot sparks",
        params = {
            emitterType = 0,
            maxParticles = 400,             -- Many tiny particles
            angle = -90,
            angleVariance = 30,             -- Wider cone for spray pattern
            speed = 250,                    -- Fast ejection
            speedVariance = 50,
            sourcePositionVariancex = 3,    -- Point source
            sourcePositionVariancey = 3,
            particleLifespan = 0.5,         -- Very short life
            particleLifespanVariance = 0.2,
            startParticleSize = 8,          -- Small bright dots
            startParticleSizeVariance = 3,
            finishParticleSize = 3,
            finishParticleSizeVariance = 2,
            startColorRed = 1,              -- Hot yellow-white
            startColorGreen = 0.8,
            startColorBlue = 0.2,
            startColorAlpha = 1,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0.1,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0,
            finishColorRed = 1,             -- Cools to deep orange
            finishColorGreen = 0.3,
            finishColorBlue = 0,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 200,                 -- Gravity pulls sparks down (arc)
            blendFuncSource = 770,
            blendFuncDestination = 1,       -- Additive for bright glow
            textureFileName = "assets/particles/spark_01.png",
        },
    },

    -- Downward rain effect. Wide source variance to cover screen width.
    -- Slightly angled (100°) for wind effect. Short life, fast speed.
    rain = {
        name = "Rain",
        description = "Falling rain droplets",
        params = {
            emitterType = 0,
            maxParticles = 500,             -- Dense rainfall
            angle = 100,                    -- Slightly off-vertical for wind
            angleVariance = 5,              -- Very narrow for parallel streaks
            speed = 450,                    -- Fast falling speed
            speedVariance = 50,
            sourcePositionVariancex = 400,  -- Wide source covers full screen
            sourcePositionVariancey = 0,
            particleLifespan = 0.8,
            particleLifespanVariance = 0.2,
            startParticleSize = 4,          -- Tiny elongated drops
            startParticleSizeVariance = 2,
            finishParticleSize = 4,         -- Constant size
            finishParticleSizeVariance = 1,
            startColorRed = 0.6,            -- Light blue-white
            startColorGreen = 0.7,
            startColorBlue = 1,
            startColorAlpha = 0.8,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.4,           -- Fades slightly at impact
            finishColorGreen = 0.5,
            finishColorBlue = 1,
            finishColorAlpha = 0.3,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,                   -- No additional gravity (speed handles it)
            gravityy = 0,
            blendFuncSource = 770,
            blendFuncDestination = 771,     -- Normal blending for opaque drops
            textureFileName = "assets/particles/basic_rect_01.png",
        },
    },

    -- Slow drifting snowflakes with rotation and tangential wobble.
    -- Wide source, long lifespan, gentle lateral drift.
    snow = {
        name = "Snow",
        description = "Gently falling snowflakes",
        params = {
            emitterType = 0,
            maxParticles = 300,
            angle = 90,                     -- Fall downward
            angleVariance = 15,
            speed = 20,                     -- Very slow drift
            speedVariance = 10,
            sourcePositionVariancex = 400,  -- Wide source covers screen
            sourcePositionVariancey = 0,
            particleLifespan = 5,           -- Long life for slow descent
            particleLifespanVariance = 1,
            startParticleSize = 10,
            startParticleSizeVariance = 5,
            finishParticleSize = 8,
            finishParticleSizeVariance = 3,
            rotationStart = 0,              -- Tumbling rotation for realism
            rotationStartVariance = 180,
            rotationEnd = 180,
            rotationEndVariance = 180,
            startColorRed = 1,              -- Pure white
            startColorGreen = 1,
            startColorBlue = 1,
            startColorAlpha = 0.9,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 1,
            finishColorGreen = 1,
            finishColorBlue = 1,
            finishColorAlpha = 0.2,         -- Fades before reaching ground
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = -5,                  -- Slight lateral wind drift
            gravityy = 0,
            tangentialAcceleration = 5,     -- Wobble for floating feel
            tangentialAccelVariance = 10,
            blendFuncSource = 770,
            blendFuncDestination = 771,     -- Normal blending
        },
    },

    -- Short-duration burst. Emits in all directions (360° variance) with
    -- radial deceleration to simulate shockwave then falloff.
    explosion = {
        name = "Explosion",
        description = "Explosive burst effect",
        params = {
            emitterType = 0,
            maxParticles = 500,             -- Many particles for dense burst
            duration = 0.1,                 -- Very short burst (not continuous)
            angle = 0,
            angleVariance = 180,            -- Full 360° emission
            speed = 300,                    -- High initial velocity
            speedVariance = 100,
            sourcePositionVariancex = 0,    -- Point source
            sourcePositionVariancey = 0,
            particleLifespan = 0.6,         -- Quick fade after burst
            particleLifespanVariance = 0.2,
            startParticleSize = 30,         -- Large initial debris
            startParticleSizeVariance = 10,
            finishParticleSize = 5,
            finishParticleSizeVariance = 3,
            startColorRed = 1,              -- Hot orange core
            startColorGreen = 0.5,
            startColorBlue = 0.1,
            startColorAlpha = 1,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0.1,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0,
            finishColorRed = 1,             -- Cools to red, fades
            finishColorGreen = 0.2,
            finishColorBlue = 0,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            radialAcceleration = -200,      -- Inward pull slows expansion
            radialAccelVariance = 50,
            blendFuncSource = 770,
            blendFuncDestination = 1,       -- Additive for bright flash
        },
    },

    -- Slow rising bubbles that grow in size. Tangential acceleration
    -- adds sideways wobble. Normal blending for translucent appearance.
    bubbles = {
        name = "Bubbles",
        description = "Rising underwater bubbles",
        params = {
            emitterType = 0,
            maxParticles = 100,             -- Sparse for realism
            angle = -90,                    -- Rise upward
            angleVariance = 20,
            speed = 40,                     -- Slow gentle rise
            speedVariance = 15,
            sourcePositionVariancex = 30,
            sourcePositionVariancey = 10,
            particleLifespan = 4,           -- Long life for slow ascent
            particleLifespanVariance = 1,
            startParticleSize = 8,          -- Small bubbles grow as they rise
            startParticleSizeVariance = 3,
            finishParticleSize = 30,
            finishParticleSizeVariance = 10,
            startColorRed = 0.5,            -- Light blue tint
            startColorGreen = 0.7,
            startColorBlue = 1,
            startColorAlpha = 0.4,          -- Very translucent
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.6,
            finishColorGreen = 0.8,
            finishColorBlue = 1,
            finishColorAlpha = 0.1,         -- Almost invisible at top
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = -15,                 -- Gentle buoyancy
            tangentialAcceleration = 10,    -- Wobble left-right as they rise
            tangentialAccelVariance = 20,
            blendFuncSource = 770,
            blendFuncDestination = 771,     -- Normal blend for translucency
        },
    },

    -- Wide-source falling confetti with high color variance for rainbow effect.
    -- Rotation and tangential acceleration create tumbling motion.
    confetti = {
        name = "Confetti",
        description = "Colorful celebration confetti",
        params = {
            emitterType = 0,
            maxParticles = 300,
            angle = 90,                     -- Fall downward
            angleVariance = 30,
            speed = 60,
            speedVariance = 30,
            sourcePositionVariancex = 200,  -- Wide source for coverage
            sourcePositionVariancey = 0,
            particleLifespan = 3,
            particleLifespanVariance = 1,
            startParticleSize = 12,
            startParticleSizeVariance = 4,
            finishParticleSize = 10,
            finishParticleSizeVariance = 3,
            rotationStart = 0,              -- Full tumble rotation
            rotationStartVariance = 180,
            rotationEnd = 360,
            rotationEndVariance = 180,
            startColorRed = 1,              -- Base pink-ish
            startColorGreen = 0.5,
            startColorBlue = 0.5,
            startColorAlpha = 1,
            startColorVarianceRed = 0.5,    -- High variance = rainbow colors
            startColorVarianceGreen = 0.5,
            startColorVarianceBlue = 0.5,
            startColorVarianceAlpha = 0,
            finishColorRed = 1,
            finishColorGreen = 0.5,
            finishColorBlue = 0.5,
            finishColorAlpha = 0.5,         -- Fades to half opacity
            finishColorVarianceRed = 0.5,
            finishColorVarianceGreen = 0.5,
            finishColorVarianceBlue = 0.5,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 30,                  -- Light gravity for gentle fall
            tangentialAcceleration = 15,    -- Swaying drift
            tangentialAccelVariance = 30,
            blendFuncSource = 770,
            blendFuncDestination = 771,     -- Normal blend for opaque pieces
        },
    },

    -- Very few, long-lived particles with large source spread. Slow random
    -- drift with tangential wobble. Yellow-green glow, additive blending.
    fireflies = {
        name = "Fireflies",
        description = "Soft glowing fireflies",
        params = {
            emitterType = 0,
            maxParticles = 40,              -- Very few for ambient feel
            angle = -90,
            angleVariance = 180,            -- All directions for random wandering
            speed = 15,                     -- Very slow drift
            speedVariance = 10,
            sourcePositionVariancex = 200,  -- Large area coverage
            sourcePositionVariancey = 150,
            particleLifespan = 6,           -- Long life for slow blinking
            particleLifespanVariance = 2,
            startParticleSize = 12,
            startParticleSizeVariance = 5,
            finishParticleSize = 8,
            finishParticleSizeVariance = 3,
            startColorRed = 0.7,            -- Yellow-green bioluminescence
            startColorGreen = 1,
            startColorBlue = 0.2,
            startColorAlpha = 0.8,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.3,  -- Varying brightness for blinking
            finishColorRed = 0.5,
            finishColorGreen = 0.8,
            finishColorBlue = 0.1,
            finishColorAlpha = 0,           -- Fade out completely
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            tangentialAcceleration = 8,     -- Gentle wobble for organic movement
            tangentialAccelVariance = 15,
            blendFuncSource = 770,
            blendFuncDestination = 1,       -- Additive for soft glow
        },
    },

    -- Small bright sparkles with additive blending for a glinting effect.
    -- Few particles, pure white, scattered over a wide area.
    glimmer = {
        name = "Glimmer",
        description = "Bright glinting sparkles",
        params = {
            emitterType = 0,
            maxParticles = 50,
            angle = -90,
            angleVariance = 180,
            speed = 5,
            speedVariance = 3,
            sourcePositionVariancex = 200,
            sourcePositionVariancey = 150,
            particleLifespan = 0.8,
            particleLifespanVariance = 0.4,
            startParticleSize = 8,
            startParticleSizeVariance = 4,
            finishParticleSize = 2,
            finishParticleSizeVariance = 1,
            startColorRed = 1,
            startColorGreen = 1,
            startColorBlue = 1,
            startColorAlpha = 1,
            startColorVarianceRed = 0,
            startColorVarianceGreen = 0,
            startColorVarianceBlue = 0.1,
            startColorVarianceAlpha = 0.3,
            finishColorRed = 0.8,
            finishColorGreen = 0.9,
            finishColorBlue = 1,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 0,
            blendFuncSource = 770,
            blendFuncDestination = 1,
            textureFileName = "assets/particles/star_01.png",
        },
    },

    -- Large spinning magical vortex. Particles orbit with blue-cyan-purple
    -- color shift. Additive blending for energy glow. Star texture.
    magicVortex = {
        name = "Magic Vortex",
        description = "Large spinning magical vortex with star particles",
        params = {
            emitterType = 1,
            maxParticles = 400,
            particleLifespan = 2.5,
            particleLifespanVariance = 0.8,
            startParticleSize = 30,
            startParticleSizeVariance = 10,
            finishParticleSize = 10,
            finishParticleSizeVariance = 4,
            startColorRed = 0.2,
            startColorGreen = 0.5,
            startColorBlue = 1,
            startColorAlpha = 1,
            startColorVarianceRed = 0.2,
            startColorVarianceGreen = 0.3,
            startColorVarianceBlue = 0.1,
            startColorVarianceAlpha = 0,
            finishColorRed = 0.5,
            finishColorGreen = 0.1,
            finishColorBlue = 1,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0.1,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            maxRadius = 140,
            maxRadiusVariance = 30,
            minRadius = 10,
            minRadiusVariance = 5,
            rotatePerSecond = 200,
            rotatePerSecondVariance = 40,
            blendFuncSource = 770,
            blendFuncDestination = 1,
            textureFileName = "assets/particles/basic_star_02.png",
        },
    },

    -- Electrical sparks from wires or machinery. Short-lived, very fast
    -- particles with blue-white color. Additive blending for bright arcs.
    electricSparks = {
        name = "Electric Sparks",
        description = "Fast electrical sparks from wires or panels",
        params = {
            emitterType = 0,
            maxParticles = 300,
            angle = -90,
            angleVariance = 60,
            speed = 200,
            speedVariance = 100,
            sourcePositionVariancex = 5,
            sourcePositionVariancey = 5,
            particleLifespan = 0.3,
            particleLifespanVariance = 0.15,
            startParticleSize = 6,
            startParticleSizeVariance = 3,
            finishParticleSize = 2,
            finishParticleSizeVariance = 1,
            startColorRed = 0.6,
            startColorGreen = 0.8,
            startColorBlue = 1,
            startColorAlpha = 1,
            startColorVarianceRed = 0.2,
            startColorVarianceGreen = 0.1,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0,
            finishColorRed = 0.3,
            finishColorGreen = 0.4,
            finishColorBlue = 1,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 150,
            tangentialAcceleration = 20,
            tangentialAccelVariance = 40,
            blendFuncSource = 770,
            blendFuncDestination = 1,
            textureFileName = "assets/particles/spark_01.png",
        },
    },

    -- Large chaotic inward-spiraling vortex. Blue-teal palette with fast
    -- rotation, high variance for violent turbulent motion. Additive blending.
    whirlpool = {
        name = "Whirlpool",
        description = "Large chaotic spiraling vortex",
        params = {
            emitterType = 1,
            maxParticles = 500,
            particleLifespan = 2.5,
            particleLifespanVariance = 1.5,
            startParticleSize = 30,
            startParticleSizeVariance = 15,
            finishParticleSize = 8,
            finishParticleSizeVariance = 6,
            startColorRed = 0.1,
            startColorGreen = 0.6,
            startColorBlue = 1,
            startColorAlpha = 0.9,
            startColorVarianceRed = 0.2,
            startColorVarianceGreen = 0.3,
            startColorVarianceBlue = 0.1,
            startColorVarianceAlpha = 0.2,
            finishColorRed = 0,
            finishColorGreen = 0.3,
            finishColorBlue = 0.8,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0.1,
            finishColorVarianceGreen = 0.2,
            finishColorVarianceBlue = 0.1,
            finishColorVarianceAlpha = 0,
            maxRadius = 200,
            maxRadiusVariance = 60,
            minRadius = 5,
            minRadiusVariance = 5,
            rotatePerSecond = 300,
            rotatePerSecondVariance = 120,
            blendFuncSource = 770,
            blendFuncDestination = 1,
            textureFileName = "assets/particles/twirl_01.png",
        },
    },

    -- Explosive firework burst with confetti-like colorful particles.
    -- Gravity emitter with 360° spread, short burst, tumbling rectangles.
    firework = {
        name = "Firework",
        description = "Explosive burst with colorful confetti particles",
        params = {
            emitterType = 0,
            maxParticles = 500,
            duration = 0.1,
            angle = 0,
            angleVariance = 180,
            speed = 350,
            speedVariance = 100,
            sourcePositionVariancex = 0,
            sourcePositionVariancey = 0,
            particleLifespan = 1.5,
            particleLifespanVariance = 0.5,
            startParticleSize = 15,
            startParticleSizeVariance = 5,
            finishParticleSize = 8,
            finishParticleSizeVariance = 3,
            rotationStart = 0,
            rotationStartVariance = 180,
            rotationEnd = 360,
            rotationEndVariance = 180,
            startColorRed = 1,
            startColorGreen = 0.5,
            startColorBlue = 0.5,
            startColorAlpha = 1,
            startColorVarianceRed = 0.5,
            startColorVarianceGreen = 0.5,
            startColorVarianceBlue = 0.5,
            startColorVarianceAlpha = 0,
            finishColorRed = 1,
            finishColorGreen = 0.5,
            finishColorBlue = 0.5,
            finishColorAlpha = 0.3,
            finishColorVarianceRed = 0.5,
            finishColorVarianceGreen = 0.5,
            finishColorVarianceBlue = 0.5,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 150,
            blendFuncSource = 770,
            blendFuncDestination = 771,
            textureFileName = "assets/particles/basic_rect_01.png",
        },
    },

    -- Continuous hollow circles collapsing inward from a large radius,
    -- creating a mesmerizing looping ring effect. Radial emitter.
    circle = {
        name = "Circle",
        description = "Hollow circles collapsing inward in a loop",
        params = {
            emitterType = 1,
            maxParticles = 200,
            particleLifespan = 1.2,
            particleLifespanVariance = 0.3,
            startParticleSize = 30,
            startParticleSizeVariance = 8,
            finishParticleSize = 6,
            finishParticleSizeVariance = 2,
            startColorRed = 0.6,
            startColorGreen = 0.9,
            startColorBlue = 1,
            startColorAlpha = 0.9,
            startColorVarianceRed = 0.2,
            startColorVarianceGreen = 0.1,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.3,
            finishColorGreen = 0.6,
            finishColorBlue = 1,
            finishColorAlpha = 0,
            finishColorVarianceRed = 0.1,
            finishColorVarianceGreen = 0.1,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            maxRadius = 100,
            maxRadiusVariance = 20,
            minRadius = 5,
            minRadiusVariance = 3,
            rotatePerSecond = 60,
            rotatePerSecondVariance = 30,
            blendFuncSource = 770,
            blendFuncDestination = 1,
            textureFileName = "assets/particles/basic_circle_02.png",
        },
    },

    -- Large upward water spray arcing back down. Blue-white droplets with
    -- strong downward gravity creating parabolic trajectories.
    waterFountain = {
        name = "Water Fountain",
        description = "Large upward water spray arcing back down",
        params = {
            emitterType = 0,
            maxParticles = 250,
            angle = -90,
            angleVariance = 15,
            speed = 400,
            speedVariance = 80,
            sourcePositionVariancex = 10,
            sourcePositionVariancey = 6,
            particleLifespan = 1.8,
            particleLifespanVariance = 0.4,
            startParticleSize = 20,
            startParticleSizeVariance = 6,
            finishParticleSize = 12,
            finishParticleSizeVariance = 4,
            startColorRed = 0.6,
            startColorGreen = 0.8,
            startColorBlue = 1,
            startColorAlpha = 0.8,
            startColorVarianceRed = 0.05,
            startColorVarianceGreen = 0.05,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.3,
            finishColorGreen = 0.5,
            finishColorBlue = 1,
            finishColorAlpha = 0.2,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 500,
            blendFuncSource = 770,
            blendFuncDestination = 771,
            textureFileName = "assets/particles/basic_circle_01.png",
        },
    },

    -- Continuous downward flow of water. Wide horizontal source with
    -- fast downward speed. Blue-white, semi-transparent, normal blending.
    waterfall = {
        name = "Waterfall",
        description = "Continuous cascading water flow",
        params = {
            emitterType = 0,
            maxParticles = 800,
            angle = 90,
            angleVariance = 8,
            speed = 280,
            speedVariance = 30,
            sourcePositionVariancex = 60,
            sourcePositionVariancey = 3,
            particleLifespan = 1,
            particleLifespanVariance = 0.5,
            startParticleSize = 14,
            startParticleSizeVariance = 4,
            finishParticleSize = 20,
            finishParticleSizeVariance = 5,
            startColorRed = 0.7,
            startColorGreen = 0.85,
            startColorBlue = 1,
            startColorAlpha = 0.6,
            startColorVarianceRed = 0.05,
            startColorVarianceGreen = 0.05,
            startColorVarianceBlue = 0,
            startColorVarianceAlpha = 0.1,
            finishColorRed = 0.4,
            finishColorGreen = 0.6,
            finishColorBlue = 1,
            finishColorAlpha = 0.15,
            finishColorVarianceRed = 0,
            finishColorVarianceGreen = 0,
            finishColorVarianceBlue = 0,
            finishColorVarianceAlpha = 0,
            gravityx = 0,
            gravityy = 250,
            tangentialAcceleration = 5,
            tangentialAccelVariance = 10,
            blendFuncSource = 770,
            blendFuncDestination = 771,
            textureFileName = "assets/particles/basic_circle_01.png",
        },
    },
}

local templateOrder = {
    -- Fire effects
    "fire",
    "smoke",
    "sparks",
    "electricSparks",
    -- Weather
    "rain",
    "snow",
    "glimmer",
    -- Nature
    "bubbles",
    "fireflies",
    -- Water
    "waterFountain",
    "waterfall",
    -- Effects
    "explosion",
    "confetti",
    -- Radial / Energy
    "magicVortex",
    "whirlpool",
    "firework",
    "circle",
}

function M.get( templateId )
    local template = templates[templateId]
    if template then
        local params = {}
        for k, v in pairs( template.params ) do
            params[k] = v
        end
        return params
    end
    return nil
end

function M.getDefault()
    return M.get( "fire" )
end

function M.getList()
    local list = {}
    for _, id in ipairs( templateOrder ) do
        local template = templates[id]
        list[#list + 1] = {
            id = id,
            name = template.name,
            description = template.description,
        }
    end
    return list
end

function M.exists( templateId )
    return templates[templateId] ~= nil
end

return M
