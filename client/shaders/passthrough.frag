uniform sampler2D inFboTexture;
varying vec2 fragTexCoord0;

void main(void) {
  gl_FragColor = texture2D(inFboTexture, fragTexCoord0);
}
