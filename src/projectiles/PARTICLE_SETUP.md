# Bullet Trail Particle Setup Instructions

## Trail Particles Configuration:

### Basic Settings:
- **Emitting**: ✓ Enabled
- **Amount**: 50
- **Lifetime**: 0.5
- **Time**: 1.0
- **Speed Scale**: 1.0

### Emission:
- **Rate**: 100.0
- **Burst Count**: 0

### Particle Material (Create New ParticleProcessMaterial):

#### Direction:
- **Direction X**: 0.0
- **Direction Y**: 0.0  
- **Direction Z**: 0.0
- **Spread**: 15.0

#### Initial Velocity:
- **Velocity Min**: 20.0
- **Velocity Max**: 40.0

#### Angular Velocity:
- **Velocity Min**: -180.0
- **Velocity Max**: 180.0

#### Gravity:
- **Gravity X**: 0.0
- **Gravity Y**: 0.0
- **Gravity Z**: 0.0

#### Scale:
- **Scale Min**: 0.1
- **Scale Max**: 0.3
- **Scale Curve**: Create AnimationCurve - start at 1.0, end at 0.0

#### Color:
- **Color**: Yellow (1, 1, 0, 1)
- **Color Ramp**: Create Gradient - start opaque yellow, fade to transparent

#### Additional:
- **Trail Enabled**: ✓
- **Trail Length Multiplier**: 2.0

### Texture:
- Use built-in circle texture or create custom spark texture
