default:
    @just --list

# Render hose segments: size, how two fit together, and the refusals
test:
    python3 tests/test_segmented_hose.py

# Render the README picture into assets/
images:
    @mkdir -p assets
    openscad --camera=0,0,20,70,0,30,110 --imgsize=600,600 --colorscheme=Tomorrow -D segments=3 -o assets/three-segments.png segmented_hose.scad
