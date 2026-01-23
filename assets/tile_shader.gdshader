shader_type canvas_item;

// ============================================================================
// PREMIUM ANIMATED GRASS TILE SHADER
// Award-winning visuals with animated grass, glow effects, and smooth transitions
// ============================================================================

// Tile state uniforms
uniform vec4 base_color_a : source_color = vec4(0.22, 0.45, 0.25, 1.0);  // Rich grass green
uniform vec4 base_color_b : source_color = vec4(0.18, 0.38, 0.20, 1.0);  // Darker grass green
uniform bool is_alt_tile = false;

// State highlighting
uniform bool is_move_range = false;
uniform bool is_spell_range = false;
uniform bool is_blocked = false;
uniform bool is_hovered = false;
uniform bool is_aoe_preview = false;
uniform bool is_path_preview = false;
uniform bool is_obstacle = false;

// Animation timing
uniform float time_scale : hint_range(0.5, 3.0) = 1.0;

// Premium colors for states
uniform vec4 move_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 spell_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 aoe_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform vec4 path_color : source_color = vec4(0.3, 1.0, 0.7, 1.0);

// Obstacle colors
uniform vec4 obstacle_color_a : source_color = vec4(0.38, 0.36, 0.42, 1.0);
uniform vec4 obstacle_color_b : source_color = vec4(0.32, 0.30, 0.36, 1.0);

// Simple hash function for noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simple noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Multi-octave noise (unrolled)
float multi_noise(vec2 p) {
    float value = 0.0;
    value += noise(p) * 0.5;
    value += noise(p * 2.0) * 0.25;
    value += noise(p * 4.0) * 0.125;
    return value;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_scale;
    
    // ========================================================================
    // OBSTACLE TILES - Stone with subtle shimmer
    // ========================================================================
    
    if (is_obstacle) {
        vec4 color_primary = obstacle_color_a;
        vec4 color_secondary = obstacle_color_b;
        
        float stone_pattern = noise(uv * 6.0);
        vec4 tile_color = mix(color_primary, color_secondary, stone_pattern);
        
        // Subtle light shimmer
        float shimmer = sin(t * 0.5 + uv.x * 5.0 + uv.y * 3.0) * 0.03 + 1.0;
        tile_color.rgb *= shimmer;
        
        // Edge darkening
        float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float edge_shadow = smoothstep(0.0, 0.15, edge_dist);
        tile_color.rgb *= mix(0.7, 1.0, edge_shadow);
        
        COLOR = tile_color;
        return;
    }
    
    // ========================================================================
    // GRASS TILES - Animated flowing grass
    // ========================================================================
    
    vec4 color_primary = is_alt_tile ? base_color_b : base_color_a;
    vec4 color_secondary = is_alt_tile ? base_color_a : base_color_b;
    
    // Animated grass waves
    float wave1 = sin(uv.x * 8.0 + t * 1.5) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 6.0 + t * 1.2 + 1.5) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 5.0 + t * 1.8) * 0.5 + 0.5;
    float grass_wave = wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25;
    
    // Grass texture noise
    float grass_noise = multi_noise(uv * 8.0 + vec2(t * 0.1, t * 0.05));
    
    // Mix colors for grass variation
    float color_blend = grass_wave * 0.6 + grass_noise * 0.3;
    vec4 tile_color = mix(color_primary, color_secondary, color_blend);
    
    // Grass brightness variation (catching light)
    float brightness = grass_wave * 0.08;
    tile_color.rgb += brightness * vec3(0.1, 0.15, 0.03);
    
    // Dark patches for depth
    float dark_patches = smoothstep(0.3, 0.5, grass_noise);
    tile_color.rgb = mix(tile_color.rgb * 0.88, tile_color.rgb, dark_patches);
    
    // ========================================================================
    // EDGE EFFECTS - Premium beveled look
    // ========================================================================
    
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    
    // Inner highlight
    float highlight_mask = smoothstep(0.0, 0.12, edge_dist);
    float highlight = (1.0 - uv.x * 0.3) * (1.0 - uv.y * 0.3);
    tile_color.rgb = mix(tile_color.rgb * 0.85, tile_color.rgb * (1.0 + highlight * 0.12), highlight_mask);
    
    // Edge darkening
    float edge_shadow = smoothstep(0.0, 0.08, edge_dist);
    tile_color.rgb *= mix(0.78, 1.0, edge_shadow);
    
    // ========================================================================
    // STATE HIGHLIGHTING
    // ========================================================================
    
    if (is_blocked) {
        // Blocked: Dramatic darkening
        float gray = dot(tile_color.rgb, vec3(0.299, 0.587, 0.114));
        tile_color.rgb = mix(vec3(gray), tile_color.rgb, 0.2) * 0.35;
        float dark_pulse = sin(t * 2.0) * 0.05 + 0.95;
        tile_color.rgb *= dark_pulse;
        
    } else if (is_move_range) {
        // MOVEMENT RANGE - Blue glow with sparkles
        float pulse = sin(t * 2.5) * 0.15 + 0.85;
        float center_dist = length(uv - 0.5) * 2.0;
        float glow = 1.0 - smoothstep(0.0, 1.0, center_dist);
        glow = pow(glow, 0.8);
        
        // Animated ring
        float ring = sin(center_dist * 8.0 - t * 3.0) * 0.5 + 0.5;
        ring = smoothstep(0.3, 0.7, ring) * 0.3;
        
        vec3 move_glow = move_color.rgb * (glow * 0.5 + ring + 0.3) * pulse;
        tile_color.rgb = mix(tile_color.rgb, tile_color.rgb + move_glow, 0.7);
        tile_color.rgb *= 1.15;
        
        // Sparkles
        float sparkle = pow(noise(uv * 20.0 + t * 2.0), 8.0) * 1.5;
        tile_color.rgb += vec3(0.3, 0.6, 1.0) * sparkle;
        
    } else if (is_spell_range) {
        // SPELL RANGE - Golden magical glow
        float pulse = sin(t * 3.0) * 0.12 + 0.88;
        float angle = atan(uv.y - 0.5, uv.x - 0.5);
        float swirl = sin(angle * 4.0 + t * 2.0 + length(uv - 0.5) * 10.0) * 0.5 + 0.5;
        
        float center_dist = length(uv - 0.5) * 2.0;
        float glow = 1.0 - smoothstep(0.0, 1.0, center_dist);
        glow = pow(glow, 0.7);
        
        vec3 spell_glow = spell_color.rgb * (glow * 0.6 + swirl * 0.25 + 0.2) * pulse;
        tile_color.rgb = mix(tile_color.rgb, tile_color.rgb * 0.8 + spell_glow, 0.65);
        
        // Edge highlight
        float edge_glow = 1.0 - smoothstep(0.0, 0.15, edge_dist);
        tile_color.rgb += spell_color.rgb * edge_glow * 0.4 * pulse;
    }
    
    // AOE PREVIEW - Fiery danger zone
    if (is_aoe_preview) {
        float pulse = sin(t * 4.0) * 0.2 + 0.8;
        float fire_noise = noise(uv * 5.0 + vec2(0.0, -t * 2.0));
        float fire = smoothstep(0.3, 0.6, fire_noise);
        
        float center_dist = length(uv - 0.5);
        float intensity = 1.0 - center_dist * 0.5;
        
        vec3 fire_color = mix(aoe_color.rgb, vec3(1.0, 0.8, 0.2), fire * 0.5);
        tile_color.rgb = mix(tile_color.rgb, fire_color, 0.55 * pulse * intensity);
        
        float edge_heat = 1.0 - smoothstep(0.0, 0.12, edge_dist);
        tile_color.rgb += aoe_color.rgb * edge_heat * 0.6;
    }
    
    // PATH PREVIEW - Mint green trail
    if (is_path_preview) {
        float flow = sin(uv.x * 10.0 + uv.y * 10.0 - t * 4.0) * 0.5 + 0.5;
        flow = smoothstep(0.3, 0.7, flow);
        
        float center_dist = length(uv - 0.5);
        float glow = 1.0 - smoothstep(0.0, 0.7, center_dist);
        
        vec3 path_glow = path_color.rgb * (glow * 0.5 + flow * 0.3 + 0.3);
        tile_color.rgb = mix(tile_color.rgb, tile_color.rgb + path_glow, 0.6);
        
        float particles = pow(noise(uv * 15.0 + vec2(-t * 3.0, -t * 2.0)), 6.0) * 2.0;
        tile_color.rgb += path_color.rgb * particles;
    }
    
    // HOVER - Premium white glow
    if (is_hovered) {
        float hover_pulse = sin(t * 4.0) * 0.1 + 0.9;
        float edge_glow = 1.0 - smoothstep(0.0, 0.2, edge_dist);
        edge_glow = pow(edge_glow, 0.7);
        
        float center_boost = 1.0 - length(uv - 0.5) * 0.8;
        
        tile_color.rgb += vec3(1.0) * edge_glow * 0.8 * hover_pulse;
        tile_color.rgb *= 1.0 + center_boost * 0.2 * hover_pulse;
        
        // Subtle color shimmer
        float hue_shift = sin(t * 2.0 + uv.x * 5.0) * 0.05;
        tile_color.r += hue_shift * edge_glow;
        tile_color.b -= hue_shift * edge_glow;
    }
    
    COLOR = tile_color;
}
