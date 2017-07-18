uniform sampler2D inFboTexture;
varying vec2 fragTexCoord0;
uniform bool inIsLmbDown;
uniform bool inIsRmbDown;
uniform bool inWasLmbUp;
uniform bool inWasRmbUp;

void main(void) {
    gl_FragColor = texture2D(inFboTexture, fragTexCoord0);

}
