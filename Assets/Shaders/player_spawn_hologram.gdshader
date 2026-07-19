/*
Shader adapted from Godot Shaders:
godotshaders.com/shader/teleport-effect

Original shader released under the CC0 license.
Modified for Godot 4.7 and the player spawn system.
*/

shader_type canvas_item;

/* SHADER SETTINGS */

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float noise_density : hint_range(
	1.0,
	200.0,
	1.0
) = 60.0;

uniform float beam_size : hint_range(
	0.01,
	0.15,
	0.005
) = 0.05;

uniform vec4 beam_color : source_color = vec4(
	0.0,
	0.85,
	1.0,
	1.0
);

uniform float beam_intensity : hint_range(
	0.0,
	5.0,
	0.1
) = 1.5;

/* RANDOM NOISE */

vec2 random_gradient(vec2 coordinates) {
	coordinates = vec2(
		dot(
			coordinates,
			vec2(127.1, 311.7)
		),
		dot(
			coordinates,
			vec2(269.5, 183.3)
		)
	);
	
	return (
		-1.0
		+ 2.0
		* fract(
			sin(coordinates)
			* 43758.5453123
		)
	);
}


float generate_noise(vec2 coordinates) {
	vec2 coordinate_index = floor(coordinates);
	vec2 coordinate_fraction = fract(coordinates);
	
	vec2 blur = smoothstep(
		0.0,
		1.0,
		coordinate_fraction
	);
	
	float bottom_noise = mix(
		dot(
			random_gradient(
				coordinate_index
				+ vec2(0.0, 0.0)
			),
			coordinate_fraction
				- vec2(0.0, 0.0)
		),
		dot(
			random_gradient(
				coordinate_index
				+ vec2(1.0, 0.0)
			),
			coordinate_fraction
				- vec2(1.0, 0.0)
		),
		blur.x
	);
	
	float top_noise = mix(
		dot(
			random_gradient(
				coordinate_index
				+ vec2(0.0, 1.0)
			),
			coordinate_fraction
				- vec2(0.0, 1.0)
		),
		dot(
			random_gradient(
				coordinate_index
				+ vec2(1.0, 1.0)
			),
			coordinate_fraction
				- vec2(1.0, 1.0)
		),
		blur.x
	);
	
	return (
		mix(
			bottom_noise,
			top_noise,
			blur.y
		)
		* 0.5
		+ 0.5
	);
}


/* TELEPORT EFFECT */

void fragment() {
	/*
	COLOR already contains the sprite texture and its
	CanvasItem modulation. Using it preserves hit flashes,
	tints, transparency, and similar effects.
	*/
	vec4 texture_color = COLOR;
	
	float noise_value = (
		generate_noise(
			UV * noise_density
		)
		* UV.y
	);
	
	float body_mask = step(
		progress,
		noise_value
	);
	
	float beam_mask_with_body = step(
		progress - beam_size,
		noise_value
	);
	
	float beam_mask = (
		beam_mask_with_body
		- body_mask
	);
	
	texture_color.rgb += (
		beam_color.rgb
		* beam_mask
		* beam_intensity
	);
	
	texture_color.a *= beam_mask_with_body;
	
	COLOR = texture_color;
}