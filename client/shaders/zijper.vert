attribute vec2 inTexCoord0;
varying vec2 fragTexCoord0;

void main(void) {
  gl_Position = vec4(inTexCoord0, 0.0, 1.0);
  fragTexCoord0 = (inTexCoord0 + 1.0) / 2.0;
}
