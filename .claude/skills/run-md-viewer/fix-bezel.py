import sys
from PIL import Image, ImageDraw
for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    d = ImageDraw.Draw(im)
    # M-series iPad simulator draws a ~46px grey bezel arc in the bottom-right
    # corner; on these reader screenshots that corner is white document
    # background, so paint it white.
    d.rectangle((w - 110, h - 110, w, h), fill=(255, 255, 255))
    im.save(path)
    print("fixed", path)
