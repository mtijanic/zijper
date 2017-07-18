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

//
// Adapted sketch filter from GPUImage shaders by Brad Larson
//     https://stackoverflow.com/a/9402041
//     https://github.com/BradLarson/GPUImage
//
const vec3 W = vec3(0.2125, 0.7154, 0.0721);
void main()
{
    gl_FragColor = texture2D(inFboTexture, fragTexCoord0);
    //gl_FragColor *= vec4(1.2, 1.2, 1.2, 1.0);
    vec3 textureColor = texture2D(inFboTexture, fragTexCoord0).rgb;

    vec2 stp0 = vec2(1.0 / inScreenWidth, 0.0);
    vec2 st0p = vec2(0.0, 1.0 / inScreenHeight);
    vec2 stpp = vec2(1.0 / inScreenWidth, 1.0 / inScreenHeight);
    vec2 stpm = vec2(1.0 / inScreenWidth, -1.0 / inScreenHeight);

    float i00   = dot(textureColor, W);
    float im1m1 = dot(texture2D(inFboTexture, fragTexCoord0 - stpp).rgb, W);
    float ip1p1 = dot(texture2D(inFboTexture, fragTexCoord0 + stpp).rgb, W);
    float im1p1 = dot(texture2D(inFboTexture, fragTexCoord0 - stpm).rgb, W);
    float ip1m1 = dot(texture2D(inFboTexture, fragTexCoord0 + stpm).rgb, W);
    float im10  = dot(texture2D(inFboTexture, fragTexCoord0 - stp0).rgb, W);
    float ip10  = dot(texture2D(inFboTexture, fragTexCoord0 + stp0).rgb, W);
    float i0m1  = dot(texture2D(inFboTexture, fragTexCoord0 - st0p).rgb, W);
    float i0p1  = dot(texture2D(inFboTexture, fragTexCoord0 + st0p).rgb, W);
    float h = -im1p1 - 2.0 * i0p1 - ip1p1 + im1m1 + 2.0 * i0m1 + ip1m1;
    float v = -im1m1 - 2.0 * im10 - im1p1 + ip1m1 + 2.0 * ip10 + ip1p1;

    float mag = 1.0 - length(vec2(h, v));
    vec3 target = vec3(mag);
    if ((target.r + target.g + target.b) < 2.0)
        gl_FragColor.rgb = vec3(0.0, 0.0, 0.0);
}

