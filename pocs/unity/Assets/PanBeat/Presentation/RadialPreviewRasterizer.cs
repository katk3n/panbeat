using UnityEngine;

namespace PanBeat.Presentation
{
    public static class RadialPreviewRasterizer
    {
        public static Texture2D Render(int size = 768)
        {
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false, true);
            var pixels = new Color32[size * size];
            var background = new Color32(13, 18, 28, 255);
            for (var index = 0; index < pixels.Length; index++) pixels[index] = background;
            var center = size / 2;
            DrawCircle(pixels, size, center, center, (int)(size * 0.425), 3, new Color32(180, 190, 205, 255));
            DrawCircle(pixels, size, center, center, (int)(size * 0.225), 2, new Color32(80, 90, 105, 255));
            DrawCircle(pixels, size, center + size / 4, center + size / 5, 28, 7, new Color32(240, 240, 240, 255));
            DrawDiamond(pixels, size, center, center - size / 10, 34, new Color32(240, 240, 240, 255));
            DrawCircle(pixels, size, center, center, (int)(size * 0.34), 8, new Color32(240, 240, 240, 255));
            DrawCircle(pixels, size, center + size / 4, center + size / 5, 47, 3, new Color32(150, 160, 175, 255));
            texture.SetPixels32(pixels);
            texture.Apply(false, false);
            return texture;
        }

        private static void DrawCircle(Color32[] pixels, int size, int cx, int cy, int radius, int thickness, Color32 color)
        {
            var inner = (radius - thickness) * (radius - thickness);
            var outer = (radius + thickness) * (radius + thickness);
            for (var y = cy - radius - thickness; y <= cy + radius + thickness; y++)
            for (var x = cx - radius - thickness; x <= cx + radius + thickness; x++)
            {
                if (x < 0 || y < 0 || x >= size || y >= size) continue;
                var distance = (x - cx) * (x - cx) + (y - cy) * (y - cy);
                if (distance >= inner && distance <= outer) pixels[y * size + x] = color;
            }
        }

        private static void DrawDiamond(Color32[] pixels, int size, int cx, int cy, int radius, Color32 color)
        {
            for (var y = cy - radius; y <= cy + radius; y++)
            for (var x = cx - radius; x <= cx + radius; x++)
                if (x >= 0 && y >= 0 && x < size && y < size && Mathf.Abs(x - cx) + Mathf.Abs(y - cy) <= radius)
                    pixels[y * size + x] = color;
        }
    }
}
