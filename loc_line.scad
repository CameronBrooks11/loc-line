
$fn = $preview ? 64 : 128;

thickness = 1;
coupling_diameter = 12;
bore = 6;
slit_dim = 2;

center_distance_factor = 0.85;
top_cut_factor = 0.125;
bottom_cut_factor = 0.25;


major_diameter = coupling_diameter + thickness * 2;
center_distance = coupling_diameter * center_distance_factor;
center_distance_diff = coupling_diameter - center_distance;

top_cut = coupling_diameter * top_cut_factor;

bottom_cut = coupling_diameter * bottom_cut_factor;

module loc_line() {
  difference() {

    // Main body
    translate([0, 0, major_diameter / 2])
      union() {
        // Lower larger sphere
        sphere(d=coupling_diameter + thickness * 2);

        // Upper smaller sphere
        translate([0, 0, center_distance])
          sphere(d=coupling_diameter);
      }

    // Coupling pocket
    translate([0, 0, major_diameter / 2])
      sphere(d=coupling_diameter);

    // Cut off bottom
    translate([0, 0, bottom_cut / 2])
      cube([major_diameter, major_diameter, bottom_cut], center=true);

    // Cut off top
    translate([0, 0, -top_cut / 2 + coupling_diameter + major_diameter - thickness - center_distance_diff])
      cube([major_diameter, major_diameter, top_cut], center=true);

    // Center bore
    cylinder(d=bore, h=major_diameter * 2);

    // Chamfer
    translate([0, 0, 0])
      cylinder(d1=major_diameter - thickness, d2=0.1, h=major_diameter - center_distance_diff);

    // Relief slits
    for (i = [0:1])
      rotate([0, 0, 90 * i])
        translate([0, 0, -coupling_diameter / 2 / 2 + coupling_diameter + major_diameter - thickness - center_distance_diff])
          cube([slit_dim, major_diameter, coupling_diameter / 2], center=true);
  }
}

loc_line();
