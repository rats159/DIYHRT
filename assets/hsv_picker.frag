#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float u_hue;

out vec4 finalColor;

float hueToRgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

vec3 hsvToRgb(float h, float s, float v) {
    vec3 rgb;
    if (s == 0.0) {
        rgb = vec3(v);
    } else {
        float f = fract(h * 6.0);
        float p = v * (1.0 - s);
        float q = v * (1.0 - f * s);
        float t = v * (1.0 - (1.0 - f) * s);

        if (h < 1.0 / 6.0) rgb = vec3(v, t, p);
        else if (h < 1.0 / 3.0) rgb = vec3(q, v, p);
        else if (h < 0.5) rgb = vec3(p, v, t);
        else if (h < 2.0 / 3.0) rgb = vec3(p, q, v);
        else if (h < 5.0 / 6.0) rgb = vec3(t, p, v);
        else rgb = vec3(v, p, q);
    }
    return rgb;
}

void main()
{
    finalColor = vec4(hsvToRgb(mod(u_hue, 1),fragTexCoord.x,1-fragTexCoord.y), 1);
}
