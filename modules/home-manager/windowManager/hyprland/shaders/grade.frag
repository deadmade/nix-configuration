// Hyprland screen shader -- applied once over the fully composited screen,
// after everything else has been drawn (src/render/OpenGL.cpp, applyScreenShader).
//
// HARD CONSTRAINT: this must not reference `time` or any `pointer_*` uniform.
// Hyprland refuses those unless debug:damage_tracking = 0, which would mean a
// full 5760x1080 repaint every frame across all three outputs, forever. Static
// shaders cost one pass and are effectively free.
//
// Landmine worth remembering: Hyprland issue #14679 (closed "not planned") --
// screen shaders silently do nothing on outputs set to 10-bit or wide colour
// management. All three monitors here are XRGB8888 / cm=srgb, which is the
// working configuration. If a monitor is ever switched to bitdepth 10, this
// file stops having any effect and gives no error.

precision highp float;

varying vec2 v_texcoord;
uniform sampler2D tex;

// ---- tuning ---------------------------------------------------------------
// Deliberately gentle. The point is to feel it rather than see it; if any of
// these read as an effect, they are too high.
const float SATURATION = 1.06; // 1.0 = untouched
const float CONTRAST   = 1.03; // pivots around mid grey
const float LIFT       = 0.004; // keeps shadow detail in a very dark palette

// Vignette is OFF, and this is not timidity -- it is wrong on this machine.
// The shader runs PER MONITOR, so v_texcoord is 0..1 on each output
// independently. Any vignette therefore darkens the INNER edges of the side
// monitors too, drawing a visible dark seam down both monitor boundaries
// instead of framing one continuous 5760px desktop. Raise it only if you ever
// go single-monitor.
const float VIGNETTE        = 0.0;
const float VIGNETTE_ONSET  = 0.85; // radius where falloff begins
// ---------------------------------------------------------------------------

void main() {
    vec4 c = texture2D(tex, v_texcoord);
    vec3 col = c.rgb;

    // Saturation, pivoting on Rec.709 luma so neutrals stay neutral.
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, SATURATION);

    // Contrast around mid grey.
    col = (col - 0.5) * CONTRAST + 0.5;

    // Lift crushed blacks slightly -- the wallpaper-derived surfaces sit very
    // dark, and a touch of lift keeps them from reading as flat black.
    col += LIFT;

    if (VIGNETTE > 0.0) {
        vec2 d = v_texcoord - vec2(0.5);
        float r = length(d) * 1.41421356; // ~1.0 at the corners
        col *= 1.0 - VIGNETTE * smoothstep(VIGNETTE_ONSET, 1.0, r);
    }

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), c.a);
}
