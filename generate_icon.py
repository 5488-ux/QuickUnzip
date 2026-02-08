from PIL import Image, ImageDraw, ImageFont
import os
import math

def create_gradient(size, color1, color2):
    """Create a diagonal gradient image"""
    img = Image.new('RGBA', (size, size))
    draw = ImageDraw.Draw(img)

    for y in range(size):
        for x in range(size):
            # Diagonal gradient
            ratio = (x + y) / (2 * size)
            r = int(color1[0] + (color2[0] - color1[0]) * ratio)
            g = int(color1[1] + (color2[1] - color1[1]) * ratio)
            b = int(color1[2] + (color2[2] - color1[2]) * ratio)
            draw.point((x, y), fill=(r, g, b, 255))

    return img

def draw_rounded_rect(draw, coords, radius, fill):
    """Draw a rounded rectangle"""
    x1, y1, x2, y2 = coords
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
    draw.ellipse([x1, y1, x1 + 2*radius, y1 + 2*radius], fill=fill)
    draw.ellipse([x2 - 2*radius, y1, x2, y1 + 2*radius], fill=fill)
    draw.ellipse([x1, y2 - 2*radius, x1 + 2*radius, y2], fill=fill)
    draw.ellipse([x2 - 2*radius, y2 - 2*radius, x2, y2], fill=fill)

def create_icon(size):
    """Create the app icon"""
    # Colors - Purple gradient
    color1 = (102, 126, 234)  # #667eea
    color2 = (118, 75, 162)   # #764ba2

    # Create gradient background
    img = create_gradient(size, color1, color2)
    draw = ImageDraw.Draw(img)

    # Calculate dimensions
    center = size // 2

    # Draw a stylized zipper/archive icon
    # Main box
    box_size = int(size * 0.5)
    box_left = center - box_size // 2
    box_top = center - box_size // 2 + int(size * 0.05)
    box_right = box_left + box_size
    box_bottom = box_top + box_size

    # Draw folder/box shape
    draw_rounded_rect(draw, (box_left, box_top, box_right, box_bottom),
                     int(size * 0.05), (255, 255, 255, 230))

    # Draw zipper teeth pattern
    zipper_x = center
    zipper_width = int(size * 0.08)
    tooth_height = int(size * 0.04)
    tooth_gap = int(size * 0.06)

    # Draw zipper line
    zipper_top = box_top + int(size * 0.08)
    zipper_bottom = box_bottom - int(size * 0.08)

    # Draw zipper teeth
    y = zipper_top
    toggle = True
    while y < zipper_bottom - tooth_height:
        if toggle:
            # Left tooth
            draw.rectangle([
                zipper_x - zipper_width, y,
                zipper_x - 2, y + tooth_height
            ], fill=color1 + (255,))
        else:
            # Right tooth
            draw.rectangle([
                zipper_x + 2, y,
                zipper_x + zipper_width, y + tooth_height
            ], fill=color2 + (255,))
        y += tooth_gap
        toggle = not toggle

    # Draw zipper pull
    pull_size = int(size * 0.08)
    pull_y = zipper_top - pull_size
    draw.ellipse([
        center - pull_size, pull_y,
        center + pull_size, pull_y + pull_size * 2
    ], fill=(255, 215, 0, 255))  # Gold color

    # Draw crown/king symbol at top
    crown_y = int(size * 0.12)
    crown_height = int(size * 0.12)
    crown_width = int(size * 0.25)

    # Crown base
    crown_left = center - crown_width
    crown_right = center + crown_width

    # Draw crown points
    points = [
        (crown_left, crown_y + crown_height),
        (crown_left, crown_y + crown_height // 2),
        (crown_left + crown_width // 2, crown_y + crown_height),
        (center, crown_y),
        (crown_right - crown_width // 2, crown_y + crown_height),
        (crown_right, crown_y + crown_height // 2),
        (crown_right, crown_y + crown_height),
    ]
    draw.polygon(points, fill=(255, 215, 0, 255))  # Gold

    # Crown gems
    gem_size = int(size * 0.025)
    draw.ellipse([center - gem_size, crown_y + gem_size,
                  center + gem_size, crown_y + gem_size * 3],
                 fill=(255, 100, 100, 255))  # Red gem

    return img

def main():
    # iOS app icon sizes needed
    sizes = [
        (20, 1), (20, 2), (20, 3),
        (29, 1), (29, 2), (29, 3),
        (40, 1), (40, 2), (40, 3),
        (60, 2), (60, 3),
        (76, 1), (76, 2),
        (83.5, 2),
        (1024, 1)  # App Store
    ]

    output_dir = r"C:\Users\Admin\Desktop\QuickUnzip\QuickUnzip\Assets.xcassets\AppIcon.appiconset"

    # Create a high-res version and scale down
    master = create_icon(1024)

    contents = {
        "images": [],
        "info": {"author": "xcode", "version": 1}
    }

    for base_size, scale in sizes:
        actual_size = int(base_size * scale)
        filename = f"icon_{actual_size}x{actual_size}.png"
        filepath = os.path.join(output_dir, filename)

        # Resize the master icon
        icon = master.resize((actual_size, actual_size), Image.LANCZOS)
        icon.save(filepath, "PNG")
        print(f"Created: {filename}")

        # Add to contents
        idiom = "iphone" if base_size in [20, 29, 40, 60] else "ipad"
        if base_size == 1024:
            idiom = "ios-marketing"

        contents["images"].append({
            "filename": filename,
            "idiom": idiom,
            "scale": f"{scale}x",
            "size": f"{base_size}x{base_size}"
        })

    # Write Contents.json
    import json
    contents_path = os.path.join(output_dir, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Created: Contents.json")

if __name__ == "__main__":
    main()
