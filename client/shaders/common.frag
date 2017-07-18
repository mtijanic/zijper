varying vec2 fragTexCoord0;
uniform sampler2D inFboTexture;
uniform int inFrameNum;
uniform int inSeconds;
uniform int inElapsedUs;
uniform int inScreenWidth;
uniform int inScreenHeight;
uniform int inMouseX;
uniform int inMouseY;
uniform bool inIsLmbDown;
uniform bool inIsRmbDown;
uniform bool inWasLmbUp;
uniform bool inWasRmbUp;

const float edge_threshold  = 0.3;
const float edge_threshold2 = 5.0;


//
// Single pixel effects
//
vec3 grayscale(in vec3 pix)
{
    float f = dot(pix, vec3(0.2125, 0.7154, 0.0721));
    return vec3(f,f,f);
}

float intensity(in vec3 pix)
{
    return (pix.r + pix.g + pix.b)/3.0;
}

vec3 posterize(in vec3 pix, in float power)
{
    pix.r = ceil(pix.r * power) / power;
    pix.g = ceil(pix.g * power) / power;
    pix.b = ceil(pix.b * power) / power;
    return pix;
}


vec4 pencil(in vec4 pix)
{
    vec4 color = fwidth(pix);
    return vec4(1.-3.*min(.9,length(color)))*length(pix)/1.2;
}
vec4 pencil_color(in vec4 pix)
{
    vec4 color = fwidth(pix);
    return vec4(1.-3.*min(.9,length(color)))*length(pix)/1.2*vec4(ivec4(8.*pix))/8.;
}


//
// vec4 overloads
//
vec4 grayscale(in vec4 pix)
{
    pix.rgb = grayscale(pix.rgb);
    return pix;
}
vec4 posterize(in vec4 pix, in float power)
{
    pix.rgb = posterize(pix.rgb, power);
    return pix;
}
float intensity(in vec4 pix)
{
    return intensity(pix.rgb);
}




//
// Sampler effects
//
vec4 pixelate(in sampler2D tex, in vec2 xy, in float pixel_width, in float pixel_height)
{
    float dx = pixel_width  / inScreenWidth;
    float dy = pixel_height / inScreenHeight;
    vec2 coord = vec2(dx*floor(xy.x/dx), dy*floor(xy.y/dy));
    return texture2D(tex, coord);
}

vec4 shadowrealm(in sampler2D tex, in vec2 xy)
{
    vec4 c = texture2D(tex, xy);

    c += texture2D(tex, xy+0.001);
    c += texture2D(tex, xy+0.003);
    c += texture2D(tex, xy+0.005);
    c += texture2D(tex, xy+0.007);
    //c += texture2D(tex, xy+0.009);
    //c += texture2D(tex, xy+0.011);

    c += texture2D(tex, xy-0.001);
    c += texture2D(tex, xy-0.003);
    c += texture2D(tex, xy-0.005);
    c += texture2D(tex, xy-0.007);
    //c += texture2D(tex, xy-0.009);
    //c += texture2D(tex, xy-0.011);

    c.rgb = vec3((c.r+c.g+c.b)/3.0);
    c = c / 7.5;
    return c;
}

float edginess(in vec2 xy, in sampler2D tex, in float weight)
{
    float dx = 1.0 /float(inScreenWidth);
    float dy = 1.0 /float(inScreenHeight);

    float neighbors[9];
    neighbors[0] = intensity(texture2D(tex, xy + vec2(-1.0*dx, -1.0*dy)));
    neighbors[1] = intensity(texture2D(tex, xy + vec2(-1.0*dx,  0.0*dy)));
    neighbors[2] = intensity(texture2D(tex, xy + vec2(-1.0*dx,  1.0*dy)));
    neighbors[3] = intensity(texture2D(tex, xy + vec2( 0.0*dx, -1.0*dy)));
    neighbors[4] = intensity(texture2D(tex, xy + vec2( 0.0*dx,  0.0*dy)));
    neighbors[5] = intensity(texture2D(tex, xy + vec2( 0.0*dx,  1.0*dy)));
    neighbors[6] = intensity(texture2D(tex, xy + vec2( 1.0*dx, -1.0*dy)));
    neighbors[7] = intensity(texture2D(tex, xy + vec2( 1.0*dx,  0.0*dy)));
    neighbors[8] = intensity(texture2D(tex, xy + vec2( 1.0*dx,  1.0*dy)));

    float delta = (abs(neighbors[1]-neighbors[7]) +
                   abs(neighbors[5]-neighbors[3]) +
                   abs(neighbors[0]-neighbors[8]) +
                   abs(neighbors[2]-neighbors[6])
                  ) / 4.0;

    return clamp(weight * delta, 0.0, 1.0);
}


const float gblur_offsets[2] = float[](1.3846153846, 3.2307692308 );
const float gblur_weight[3]  = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );
vec3 gaussian_blur_vertical(in vec2 xy, in sampler2D tex)
{
    vec3 b = texture2D(tex, xy).rgb * gblur_weight[0];

    b += texture2D(tex, xy + vec2(0.0, gblur_offsets[0])/inScreenHeight).rgb * gblur_weight[1];
    b += texture2D(tex, xy - vec2(0.0, gblur_offsets[0])/inScreenHeight).rgb * gblur_weight[1];
    b += texture2D(tex, xy + vec2(0.0, gblur_offsets[1])/inScreenHeight).rgb * gblur_weight[2];
    b += texture2D(tex, xy - vec2(0.0, gblur_offsets[1])/inScreenHeight).rgb * gblur_weight[2];

    return b;
}
vec3 gaussian_blur_horizontal(in vec2 xy, in sampler2D tex)
{
    vec3 b = texture2D(tex, xy).rgb * gblur_weight[0];

    b += texture2D(tex, xy + vec2(gblur_offsets[0], 0.0)/inScreenHeight).rgb * gblur_weight[1];
    b += texture2D(tex, xy - vec2(gblur_offsets[0], 0.0)/inScreenHeight).rgb * gblur_weight[1];
    b += texture2D(tex, xy + vec2(gblur_offsets[1], 0.0)/inScreenHeight).rgb * gblur_weight[2];
    b += texture2D(tex, xy - vec2(gblur_offsets[1], 0.0)/inScreenHeight).rgb * gblur_weight[2];

    return b;
}

