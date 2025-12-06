#!/usr/bin/env python3
"""
Generate secondary_color and gradient_type values for monster species .tres files.
Run this script from the project root directory.

This script:
1. Reads each monster .tres file
2. Extracts the base_color
3. Generates a complementary/analogous secondary_color
4. Assigns a gradient_type for visual variety
5. Writes the updated values back to the file
"""

import os
import re
import colorsys
import random

# Seed for reproducible results
random.seed(42)

GRADIENT_TYPES = [
    "linear_horizontal",
    "linear_vertical", 
    "linear_diagonal_down",
    "linear_diagonal_up",
    "radial_center",
    "radial_corner",
    "diamond"
]

def parse_color(color_str):
    """Parse Color(r, g, b, a) string to tuple."""
    match = re.search(r'Color\(([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\)', color_str)
    if match:
        return (float(match.group(1)), float(match.group(2)), float(match.group(3)), float(match.group(4)))
    return None

def format_color(r, g, b, a=1.0):
    """Format color tuple to Color() string."""
    return f"Color({r:.6g}, {g:.6g}, {b:.6g}, {a})"

def rgb_to_hsv(r, g, b):
    """Convert RGB to HSV."""
    return colorsys.rgb_to_hsv(r, g, b)

def hsv_to_rgb(h, s, v):
    """Convert HSV to RGB."""
    return colorsys.hsv_to_rgb(h, s, v)

def generate_secondary_color(base_color):
    """Generate a complementary or analogous secondary color."""
    r, g, b, a = base_color
    h, s, v = rgb_to_hsv(r, g, b)
    
    # Randomly choose complementary (120-180°) or analogous (30-60°)
    if random.random() < 0.6:
        # Complementary - more dramatic
        hue_shift = random.uniform(0.33, 0.5)  # 120-180 degrees
    else:
        # Analogous - more subtle
        hue_shift = random.uniform(0.08, 0.17)  # 30-60 degrees
        if random.random() < 0.5:
            hue_shift = -hue_shift
    
    new_h = (h + hue_shift) % 1.0
    
    # Desaturate slightly (20-35%)
    new_s = max(0.15, s * random.uniform(0.65, 0.8))
    
    # Keep value similar but allow slight variation
    new_v = max(0.3, min(0.9, v * random.uniform(0.85, 1.1)))
    
    new_r, new_g, new_b = hsv_to_rgb(new_h, new_s, new_v)
    return (new_r, new_g, new_b, a)

def process_tres_file(filepath):
    """Process a single .tres file and add secondary_color and gradient_type."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Find the base_color line
    base_color_match = re.search(r'base_color\s*=\s*(Color\([^)]+\))', content)
    if not base_color_match:
        print(f"  Warning: No base_color found in {filepath}")
        return False
    
    base_color = parse_color(base_color_match.group(1))
    if not base_color:
        print(f"  Warning: Could not parse base_color in {filepath}")
        return False
    
    # Generate secondary color
    secondary = generate_secondary_color(base_color)
    secondary_str = format_color(*secondary)
    
    # Choose gradient type (distribute across files for variety)
    gradient_type = random.choice(GRADIENT_TYPES)
    
    # Check if secondary_color already exists
    if 'secondary_color' in content:
        # Update existing
        content = re.sub(
            r'secondary_color\s*=\s*Color\([^)]+\)',
            f'secondary_color = {secondary_str}',
            content
        )
    else:
        # Add after base_color line
        content = re.sub(
            r'(base_color\s*=\s*Color\([^)]+\))',
            f'\\1\nsecondary_color = {secondary_str}',
            content
        )
    
    # Check if gradient_type already exists
    if 'gradient_type' in content:
        # Update existing
        content = re.sub(
            r'gradient_type\s*=\s*"[^"]*"',
            f'gradient_type = "{gradient_type}"',
            content
        )
    else:
        # Add after secondary_color
        content = re.sub(
            r'(secondary_color\s*=\s*Color\([^)]+\))',
            f'\\1\ngradient_type = "{gradient_type}"',
            content
        )
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"  Updated: {os.path.basename(filepath)} - gradient: {gradient_type}")
    return True

def main():
    monsters_dir = "resources/monsters"
    
    if not os.path.exists(monsters_dir):
        print(f"Error: {monsters_dir} not found. Run from project root.")
        return
    
    tres_files = sorted([f for f in os.listdir(monsters_dir) if f.endswith('.tres')])
    print(f"Found {len(tres_files)} monster files")
    
    updated = 0
    for filename in tres_files:
        filepath = os.path.join(monsters_dir, filename)
        if process_tres_file(filepath):
            updated += 1
    
    print(f"\nUpdated {updated}/{len(tres_files)} files")

if __name__ == "__main__":
    main()
