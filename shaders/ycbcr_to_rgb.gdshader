// ycbcr_to_rgb.gdshader (C1_16) - draws a camera feed that arrives as two textures.
//
// modules/camera/camera_apple.mm hands frames over as separate luma and chroma images, so
// get_datatype() reports FEED_YCBCR_SEP and a single CameraTexture on a TextureRect draws a
// grey, washed-out picture that reads as a broken exposure rather than as missing colour. The
// luma image arrives as this node's own TEXTURE; the chroma image is the uniform below.
//
// The engine performs this conversion for you only when a feed is used as a 3D environment
// background. This screen draws the camera as 2D artwork behind other 2D artwork, so it does
// the conversion here.
//
// Only the two-plane case is written. The measured datatype on the handset is FEED_YCBCR_SEP
// and nothing in this application produces any other, so the interleaved and plain-RGB paths
// of the reference shader are deliberately absent rather than carried unused.
shader_type canvas_item;

// The chroma plane, bound to CameraServer.FEED_CBCR_IMAGE.
uniform sampler2D cbcr_texture;

// Video range is what AVFoundation delivers by default. If the picture comes out washed out
// (blacks grey, whites dull) this is the first thing to try at 0.
// 0 = full range, Y and CbCr both 0-255. 1 = video range, Y 16-235 and CbCr 16-240.
uniform int color_range : hint_range(0, 1) = 1;

// The selfie camera is mirrored so the photograph matches what the person framed. It is done
// here, on the camera layer alone, and never on the screen: mirroring the composed image would
// reverse the lettering and the Richmond Symphony's name in every photograph.
//
// Two flags rather than one because the picture is rotated by the node that draws it, and a
// mirror has to be a left-right flip on the *screen*, not in the texture. After a quarter or
// three-quarter turn the texture's own horizontal axis is running up and down the screen, so
// flipping it there would turn the person upside down instead of mirroring them. The caller
// sets whichever of these corresponds to screen-horizontal at the current rotation.
uniform bool mirror_u = false;
uniform bool mirror_v = false;

void fragment() {
	vec2 uv = UV;
	if (mirror_u) {
		uv.x = 1.0 - uv.x;
	}
	if (mirror_v) {
		uv.y = 1.0 - uv.y;
	}
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	float y = texture(TEXTURE, uv).r;
	vec2 cbcr = texture(cbcr_texture, uv).rg;

	vec3 ycbcr;
	if (color_range == 1) {
		ycbcr.r = (y - 16.0 / 255.0) * (255.0 / 219.0);
		ycbcr.gb = (cbcr - 16.0 / 255.0) * (255.0 / 224.0) - vec2(0.5);
	} else {
		ycbcr.r = y;
		ycbcr.gb = cbcr - vec2(0.5);
	}

	// BT.709, the standard for high-definition video.
	COLOR = vec4(mat3(
		vec3(1.00000, 1.00000, 1.00000),
		vec3(0.00000, -0.18732, 1.85560),
		vec3(1.57481, -0.46813, 0.00000)) * ycbcr, 1.0);
}
