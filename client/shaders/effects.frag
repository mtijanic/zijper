uniform sampler2D inFboTexture;
varying vec2 fragTexCoord0;

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

uniform float effIntensityRedFog;
uniform float effIntensityScreenShake;
uniform float effIntensityGrayscale;
uniform float effIntensityShadowrealm;
uniform float effIntensityUnderwater;
uniform float effIntensityBlur;

vec4 grayscale(in vec4 pix);
vec4 shadowrealm(in sampler2D tex, in vec2 xy);

vec3 gaussian_blur_vertical(in vec2 xy, in sampler2D tex);
vec3 gaussian_blur_horizontal(in vec2 xy, in sampler2D tex);

void main(void) {
    float dx = 1.0 / inScreenWidth;
    float dy = 1.0 / inScreenHeight;

    vec2 xy = fragTexCoord0;

    // Calculate image offset from screenshake
    xy.x += effIntensityScreenShake * sin(inElapsedUs)*10*dx;
    xy.y += effIntensityScreenShake * cos(inElapsedUs)*10*dy;

    // Calculate image offset from underwater
    xy.x += effIntensityUnderwater * (sin(xy.y * 4.0*2.0*3.14159 + float(inFrameNum)/100.0)) * dx * 10.0;
    gl_FragColor = texture2D(inFboTexture, xy);

    gl_FragColor = mix(gl_FragColor, grayscale(gl_FragColor),       effIntensityGrayscale);
    gl_FragColor = mix(gl_FragColor, shadowrealm(inFboTexture, xy), effIntensityShadowrealm);
    gl_FragColor = mix(gl_FragColor, vec4(1.0, 0.0, 0.0, 0.8),      effIntensityRedFog);

    gl_FragColor.rgb = mix(gl_FragColor.rgb, gaussian_blur_horizontal(xy, inFboTexture), effIntensityBlur);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, gaussian_blur_vertical(xy, inFboTexture),   effIntensityBlur);
}
