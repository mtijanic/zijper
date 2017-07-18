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

vec3 posterize(in vec3 pix, in float power);

void main()
{
    gl_FragColor = texture2D(inFboTexture, fragTexCoord0);

    gl_FragColor.r *= 2.0 - gl_FragColor.r;
    gl_FragColor.g *= 2.0 - gl_FragColor.g;
    gl_FragColor.b *= 2.0 - gl_FragColor.b;
    //gl_FragColor.rgb = posterize(gl_FragColor.rgb, 20.0);
}

