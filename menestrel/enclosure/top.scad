X = 102;
Y = 120;
Z = 11;

side_h = 3;

hole_x = 95;
hole_z = 5;

corner_dia = 7;
t = 2;
eps = 0.01;

stand_d1 = 5;
stand_h1 = 4.5;

stand_d2 = 9; // make sure it's > screw_hole_d
stand_h2 = 15;

stand_x_off = 4; // from the edge
stand_y_off = 14.5; // from the edge

stand_hole_d = 3.5;
screw_hole_d = 6;

holder_h = 10;
holder_w = 7.5;
holder_t = 5;
holder_x_off = t; // from the edge
holder_y_off = 5.5; // from the edge

din_offset = 28;
switch_hole_x_offset = 14;
switch_hole_y_offset = 63;

module din(height) {
    union() {
        cylinder(h = height, d = 15.8, $fn = 50, center = true);
        translate([-11, 0, 0])
            cylinder(h = height, d = 3.5, $fn = 20, center = true);
        translate([11, 0, 0])
            cylinder(h = height, d = 3.5, $fn = 20, center = true);
    }
}

module switch_hole(height) {
    rounded_cube(9.5, 6.5, height, 6);
}

module rounded_cube(width, height, t, dia) {
    translate([-width/2, -height/2, -t/2])
        linear_extrude(height = t)
            hull() {
                translate([dia/2, dia/2, 0])
                    circle(d = dia, $fn = 30);
                translate([dia/2, height - dia/2, 0 ])
                    circle(d = dia, $fn = 30);
                translate([width - dia/2, height - dia/2, 0])
                    circle(d = dia, $fn = 30);
                translate([width - dia/2, dia/2, 0])
                    circle(d = dia, $fn = 30);
            }
}

module screw_holder(height) {
    difference() {
        cube([holder_w, holder_t, height], center = true);
        translate([0, (holder_t-1)/2, 0])
            cube([3, 1+eps, height+eps], center = true);
        
        translate([0, 0, height/2]) rotate([90, 0, 0])
            cylinder(h = holder_t+eps, d = 3, center = true, $fn = 30);
        
        translate([0, 1/2, height/2]) rotate([90, 0, 0])
            cylinder(h = 2+eps, d = 6, center = true, $fn = 30);
    }
}

module stand() {
    difference() {
        translate([0, 0, (-stand_h1+stand_h2)/2])
            cylinder(h = stand_h2, d = stand_d2, center = true, $fn = 60);        
        cylinder(h = stand_h2*10, d = stand_d1, center = true, $fn = 60);
    }
}

module hole_under_stand() {
    cylinder(h = t*10, d = screw_hole_d, center = true, $fn = 60);
}

union() {
    difference() {
        union() {
            rounded_cube(X, Y, Z, corner_dia);
        
            translate([0,0,side_h/2])
                rounded_cube(X-1.25*t, Y-1.25*t, Z+side_h, corner_dia);
        }
        
        translate([0,0, side_h/2+t/2])
            rounded_cube(X-t*2, Y-t*2, Z+side_h-t+eps, corner_dia);
        
        translate([0, -(Y-t)/2, (Z-hole_z)/2+side_h])
            cube([hole_x, t*2, hole_z+eps], center = true);
        
        translate([(X - stand_d2)/2 - stand_x_off, (Y - stand_d2)/2 - stand_y_off, 0])
            hole_under_stand();
        translate([(-X + stand_d2)/2 + stand_x_off, (Y - stand_d2)/2 - stand_y_off, 0])
            hole_under_stand();
        translate([(X - stand_d2)/2 - stand_x_off, (-Y + stand_d2)/2 + stand_y_off, 0])
            hole_under_stand();
        translate([(-X + stand_d2)/2 + stand_x_off, (-Y + stand_d2)/2 + stand_y_off, 0])
            hole_under_stand();
        
        translate([-X/2+din_offset, Y/2-din_offset, 0])
            din(100);
        translate([X/2-switch_hole_x_offset, Y/2-switch_hole_y_offset, 0])
            switch_hole(100);
    }
    
    translate([(X-holder_w)/2 - holder_x_off, (-Y+holder_t)/2+holder_y_off, (-Z+holder_h)/2+t-eps])
        screw_holder(holder_h);
    
    translate([(-X+holder_w)/2 + holder_x_off, (-Y+holder_t)/2+holder_y_off, (-Z+holder_h)/2+t-eps])
        screw_holder(holder_h);
    
    translate([(X - stand_d2)/2 - stand_x_off, (Y - stand_d2)/2 - stand_y_off, (-Z+stand_h1)/2+t-eps]) stand();
    translate([(-X + stand_d2)/2 + stand_x_off, (Y - stand_d2)/2 - stand_y_off, (-Z+stand_h1)/2+t-eps]) stand();
    translate([(X - stand_d2)/2 - stand_x_off, (-Y + stand_d2)/2 + stand_y_off, (-Z+stand_h1)/2+t-eps]) stand();
    translate([(-X + stand_d2)/2 + stand_x_off, (-Y + stand_d2)/2 + stand_y_off, (-Z+stand_h1)/2+t-eps]) stand();

}