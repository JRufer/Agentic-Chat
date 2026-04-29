#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uSize;
uniform float uMood; // 0: professional, 1: excited, 2: angry, 3: romantic, 4: sad, 5: sarcastic
uniform vec3 uColor;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 5; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec3 finalColor = vec3(0.0);
    float alpha = 1.0;

    if (uMood < 0.5) { // Professional: Steady, rhythmic waves
        float v1 = sin(uv.x * 3.0 + uTime * 0.5);
        float v2 = sin(uv.y * 2.0 + uTime * 0.3);
        float pattern = (v1 + v2) * 0.5 + 0.5;
        finalColor = mix(vec3(0.05), uColor * 0.6, pattern * 0.4);
        
    } else if (uMood < 1.5) { // Excited: Energetic, radiating pulses
        vec2 p = uv - 0.5;
        p.x *= uSize.x / uSize.y;
        float r = length(p);
        float angle = atan(p.y, p.x);
        float pulse = sin(r * 20.0 - uTime * 8.0 + fbm(vec2(angle * 2.0, uTime)) * 2.0);
        float spark = pow(max(0.0, pulse), 5.0);
        finalColor = uColor * (0.2 + 0.8 * spark);
        
    } else if (uMood < 2.5) { // Angry: Harsh, jittery displacement
        vec2 p = uv * 8.0;
        float n = fbm(p + fbm(p + uTime * 15.0));
        float glitch = step(0.8, noise(vec2(uTime * 10.0, uv.y * 100.0)));
        finalColor = mix(uColor * 0.5, vec3(1.0, 0.1, 0.0), n);
        finalColor += glitch * vec3(0.5, 0.0, 0.0);
        
    } else if (uMood < 3.5) { // Romantic: Soft, blooming gradients
        vec2 p = uv - 0.5;
        float r = length(p);
        float bloom = smoothstep(0.7, 0.0, r + 0.1 * sin(uTime + fbm(uv * 5.0)));
        finalColor = mix(vec3(0.02, 0.0, 0.01), uColor, bloom * 0.7);
        
    } else if (uMood < 4.5) { // Sad: Downward "rain" and dim pulses
        float rain = fract(uv.y + uTime * 0.15 + hash(vec2(floor(uv.x * 20.0), 0.0)) * 5.0);
        float trail = smoothstep(0.1, 0.0, rain);
        finalColor = mix(uColor * 0.1, uColor * 0.4, trail);
        finalColor *= 0.5 + 0.5 * sin(uTime * 0.5);
        
    } else { // Sarcastic: Swirling, irregular patterns
        vec2 p = uv - 0.5;
        float angle = uTime * 1.5;
        mat2 m = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
        p = m * p;
        float swirl = fbm(p * 4.0 + uTime);
        finalColor = uColor * (0.1 + 0.9 * swirl);
    }

    // Vignette effect to keep chat readable
    float vignette = smoothstep(1.5, 0.5, length(uv - 0.5) * 1.8);
    finalColor *= vignette;

    fragColor = vec4(finalColor, 1.0);
}
