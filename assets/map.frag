#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec3 u_foreground1;
uniform vec3 u_foreground2;
uniform vec3 u_background1;
uniform vec3 u_background2;

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

float shortestHue(float h1, float h2) {
    float diff = h2 - h1;
    if (diff > 0.5) diff -= 1.0;
    if (diff < -0.5) diff += 1.0;
    return diff;
}

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord) * fragColor;
    bool is_foreground = texelColor.a == 1;
    
    vec3 left = is_foreground ? u_foreground1 : u_background1;
    vec3 right = is_foreground ? u_foreground2 : u_background2;

    float h1 = left.r;
    float h2 = right.r;
    float s = left.g + fragTexCoord.x * (right.g - left.g); 
    float v = left.b + fragTexCoord.x * (right.b - left.b);

    float hueDiff = shortestHue(h1, h2);
    float h = h1 + hueDiff * fragTexCoord.x;

    if (h < 0.0) h += 1.0;
    if (h > 1.0) h -= 1.0;

    vec3 finalColorHsv = vec3(h, s, v);
    finalColor = vec4(hsvToRgb(mod(finalColorHsv.r,1), finalColorHsv.g, finalColorHsv.b), 1);
}
