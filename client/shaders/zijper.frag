varying vec2 fragTexCoord0;
uniform sampler2D inFboTexture;
uniform int inFrameNum;
uniform int inSeconds;
uniform int inElapsedUs;
uniform int inScreenWidth;
uniform int inScreenHeight;


const float edge_threshold  = 0.2;
const float edge_threshold2 = 5.0;

float intensity(in vec4 v)
{
    return (v.r + v.g + v.b)/3.;
}

float edginess(in vec2 xy)
{
    float dx = 1.0 /float(inScreenWidth);
    float dy = 1.0 /float(inScreenHeight);

    float neighbors[9];
    neighbors[0] = intensity(texture2D(inFboTexture, xy + vec2(-1.0*dx, -1.0*dy)));
    neighbors[1] = intensity(texture2D(inFboTexture, xy + vec2(-1.0*dx,  0.0*dy)));
    neighbors[2] = intensity(texture2D(inFboTexture, xy + vec2(-1.0*dx,  1.0*dy)));
    neighbors[3] = intensity(texture2D(inFboTexture, xy + vec2( 0.0*dx, -1.0*dy)));
    neighbors[4] = intensity(texture2D(inFboTexture, xy + vec2( 0.0*dx,  0.0*dy)));
    neighbors[5] = intensity(texture2D(inFboTexture, xy + vec2( 0.0*dx,  1.0*dy)));
    neighbors[6] = intensity(texture2D(inFboTexture, xy + vec2( 1.0*dx, -1.0*dy)));
    neighbors[7] = intensity(texture2D(inFboTexture, xy + vec2( 1.0*dx,  0.0*dy)));
    neighbors[8] = intensity(texture2D(inFboTexture, xy + vec2( 1.0*dx,  1.0*dy)));

    float delta = (abs(neighbors[1]-neighbors[7]) +
                   abs(neighbors[5]-neighbors[3]) +
                   abs(neighbors[0]-neighbors[8]) +
                   abs(neighbors[2]-neighbors[6])
                  ) / 4.0;

    return clamp(edge_threshold2 * delta, 0.0, 1.0);
}

void main()
{
    vec4 outFragColor = texture2D(inFboTexture, fragTexCoord0);

    // Make everything a bit brighter
    outFragColor *= vec4(1.2, 1.2, 1.2, 1.0);

    if (edginess(fragTexCoord0) > edge_threshold)
        outFragColor *= vec4(0.1, 0.1, 0.1, 1.0);

    gl_FragColor = outFragColor;
}
