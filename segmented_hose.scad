// Segmented hose: one segment of a ball-and-socket hose, the kind used for coolant and air lines.
// Each segment has a socket at the bottom and a ball on top that snaps into the next segment's
// socket, slit so it can flex, with a bore through both. MIT licence; see LICENSE.

/* [Segment] */

// Diameter of the ball, and of the socket it snaps into, mm
coupling_diameter = 12;

// Wall thickness round the socket, mm
thickness = 1;

// Diameter of the bore through the segment, mm
bore = 6;

// Width of the two relief slits across the ball, mm
slit_dim = 1.5;

// Distance from the socket's centre to the ball's, as a fraction of coupling_diameter
center_distance_factor = 0.85;

// How much of the ball's top is cut flat, as a fraction of coupling_diameter
top_cut_factor = 0.125;

// How much of the socket's bottom is cut off to open its mouth, as a fraction of coupling_diameter
bottom_cut_factor = 0.25;

// Added to the socket's diameter: 0 is a tight fit, more is looser, mm
clearance = 0;

/* [Preview] */

// Segments in a straight chain
segments = 1;

/* [Hidden] */

$fn = $preview ? 64 : 128;

// Distance between neighbouring segments in a chain.
function segmented_hose_pitch(coupling_diameter = 12, center_distance_factor = 0.85) =
  coupling_diameter * center_distance_factor;

// The socket's mouth: its diameter at the bottom face, where the cut-off bottom and the entry flare
// open the socket. Narrower than the ball, so the ball has to snap in and stays in.
function segmented_hose_mouth(coupling_diameter = 12, thickness = 1, center_distance_factor = 0.85, bottom_cut_factor = 0.25, clearance = 0) =
  let (
    socket_r = (coupling_diameter + clearance) / 2,
    major = coupling_diameter + 2 * thickness,
    cut = coupling_diameter * bottom_cut_factor,
    // The socket's centre above the cut.
    rise = major / 2 - cut,
    sphere_mouth = rise < socket_r ? 2 * sqrt(socket_r * socket_r - rise * rise) : 0,
    flare_h = major - coupling_diameter * (1 - center_distance_factor),
    flare_mouth = (major - thickness) * (1 - cut / flare_h)
  )
  max(sphere_mouth, flare_mouth);

// One segment, its bottom face on z = 0 and its axis on z.
module segmented_hose_segment(
  coupling_diameter = 12,
  thickness = 1,
  bore = 6,
  slit_dim = 1.5,
  center_distance_factor = 0.85,
  top_cut_factor = 0.125,
  bottom_cut_factor = 0.25,
  clearance = 0
) {
  major = coupling_diameter + 2 * thickness; // the socket's outside diameter
  pitch = segmented_hose_pitch(coupling_diameter, center_distance_factor);
  socket_z = major / 2;
  ball_top = socket_z + pitch + coupling_diameter / 2;
  bottom_cut = coupling_diameter * bottom_cut_factor;
  top_cut = coupling_diameter * top_cut_factor;
  // The entry flare: a cone from the bottom up into the socket.
  flare_h = major - (coupling_diameter - pitch);
  mouth = segmented_hose_mouth(coupling_diameter, thickness, center_distance_factor, bottom_cut_factor, clearance);

  assert(coupling_diameter > 0 && thickness > 0, "segmented_hose_segment: coupling_diameter and thickness have to be more than 0");
  assert(bore >= 0 && bore < coupling_diameter - 2 * slit_dim,
         str("segmented_hose_segment: a ", bore, " mm bore leaves no wall in a ", coupling_diameter, " mm ball"));
  assert(mouth < coupling_diameter,
         str("segmented_hose_segment: the socket's mouth is ", mouth, " mm across, so a ", coupling_diameter,
             " mm ball would fall out: cut less of the bottom"));

  translate([0, 0, -bottom_cut])
    difference() {
      union() {
        translate([0, 0, socket_z]) sphere(d=major);
        translate([0, 0, socket_z + pitch]) sphere(d=coupling_diameter);
      }
      translate([0, 0, socket_z]) sphere(d=coupling_diameter + clearance);
      // Bottom off, to open the socket's mouth, and the ball's top flat.
      translate([0, 0, bottom_cut / 2]) cube([major, major, bottom_cut], center=true);
      translate([0, 0, ball_top - top_cut / 2]) cube([major, major, top_cut], center=true);
      cylinder(d=bore, h=2 * major);
      cylinder(d1=major - thickness, d2=0.1, h=flare_h);
      // Two slits across the ball's upper half, so it can flex into a socket.
      for (i = [0:1])
        rotate([0, 0, 90 * i])
          translate([0, 0, ball_top - coupling_diameter / 4])
            cube([slit_dim, major, coupling_diameter / 2], center=true);
    }
}

// The segment's height from its bottom face to the top of its ball.
function segmented_hose_height(coupling_diameter = 12, thickness = 1, center_distance_factor = 0.85, top_cut_factor = 0.125, bottom_cut_factor = 0.25) =
  (coupling_diameter + 2 * thickness) / 2 + segmented_hose_pitch(coupling_diameter, center_distance_factor)
  + coupling_diameter / 2 - coupling_diameter * top_cut_factor - coupling_diameter * bottom_cut_factor;

for (i = [0:segments - 1])
  translate([0, 0, i * segmented_hose_pitch(coupling_diameter, center_distance_factor)])
    segmented_hose_segment(coupling_diameter, thickness, bore, slit_dim, center_distance_factor, top_cut_factor, bottom_cut_factor, clearance);
