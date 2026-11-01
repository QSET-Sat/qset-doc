% 3U CubeSat Orbit Thermal Simulation — Canadian LEO Launch
% See thermal_model_reference.md for derivations, assumptions, and ideas.
% See satellite_orbit_sim_explained.m for a line-by-line commented version.

close all; clear; clc;

%% ====== CONFIGURABLE OPTIONS ======
EXPORT_VIDEO   = false;
NUM_ORBITS     = 3;
VIDEO_FPS      = 30;
SPEED_MULT     = 4;
RUN_MONTECARLO = false;
MC_RUNS        = 200;

%% --- Physical Constants ---
Re    = 6.371e6;
G     = 6.674e-11;
M_E   = 5.972e24;
sigma = 5.670e-8;

%% --- Orbit Parameters (Canadian launch) ---
alt   = 400e3;
inc   = -65;
r_orb = Re + alt;
v_orb = sqrt(G*M_E/r_orb);
omega = v_orb / r_orb;
Period = 2*pi / omega;

RAAN = 0;
sun_ecliptic = [1; 0; 0];
n_orb = [-sind(inc)*sind(RAAN); sind(inc)*cosd(RAAN); cosd(inc)];
beta_rad = asin(dot(n_orb, sun_ecliptic));
beta_deg = rad2deg(beta_rad);

%% --- 3U CubeSat Geometry (10 x 10 x 34 cm) ---
L1 = 0.10;  L2 = 0.10;  L3 = 0.34;
A_sun   = L1 * L3;
A_earth = L2 * L3;
A_total = 2*(L1*L2 + L1*L3 + L2*L3);

%% --- Satellite Thermal Properties ---
alpha_abs  = 0.6;
epsilon_ir = 0.85;
sat_mass   = 4.0;
sat_Cp     = 900;
T_init     = 253.15;

%% --- Internal Heat Dissipation (subsystem breakdown) ---
Q_obc     = 0.5;   % On-board computer [W]
Q_radio   = 2.0;   % UHF/S-band radio (avg, duty-cycled) [W]
Q_adcs    = 0.8;   % Attitude determination & control [W]
Q_payload = 1.5;   % Payload sensor/instrument [W]
Q_eps     = 0.3;   % Electrical power system losses [W]
Q_heater  = 0.0;   % Survival heater (can be toggled) [W]

Q_internal = Q_obc + Q_radio + Q_adcs + Q_payload + Q_eps + Q_heater;

%% --- Solar Panel Efficiency (body-mounted GaAs cells) ---
eta_solar  = 0.29;       % GaAs triple-junction cell efficiency
A_panel    = A_sun;       % Solar cells on sun-facing face only
P_elec_max = eta_solar * S_solar_val() * A_panel;

%% --- Solar & Earth Radiation ---
S_solar     = 1361;
albedo_eq   = 0.30;
albedo_pol  = 0.50;
T_earth_eq  = 255;
T_earth_pol = 220;
F_earth     = (Re / r_orb)^2;

%% --- Eclipse Geometry ---
rho = asin(Re / r_orb);
if abs(beta_rad) >= rho
    eclipse_half_angle = 0;
else
    eclipse_half_angle = acos(sqrt(1 - (Re/r_orb)^2) / cos(beta_rad));
end
eclipse_fraction = eclipse_half_angle / pi;
sunlit_fraction  = 1 - eclipse_fraction;

%% --- Orbital Lifetime Estimate ---
Cd = 2.2;
A_drag = L1 * L2;
BC = sat_mass / (Cd * A_drag);

H_scale = 58.515e3;
rho0_atm = 2.803e-12;
rho_atm = rho0_atm * exp(-(alt - 400e3) / H_scale);

v_circ = v_orb;
da_dt = -2 * pi * (r_orb) * rho_atm * (v_circ^2) / BC;
lifetime_s = alt / abs(da_dt);
lifetime_days = lifetime_s / 86400;
lifetime_years = lifetime_days / 365.25;

fprintf('Beta angle:          %+.1f deg\n', beta_deg);
fprintf('Eclipse fraction:    %.1f%%\n', 100*eclipse_fraction);
fprintf('Internal heat:       %.1f W\n', Q_internal);
fprintf('Est. orbital life:   %.1f years (%.0f days)\n', lifetime_years, lifetime_days);

%% --- Time Vector ---
dt = 4;
t  = 0:dt:(NUM_ORBITS * Period);
N  = length(t);

%% --- 3D Orbit Trajectory (ECI) ---
nu   = omega * t;
x_op = r_orb * cos(nu);
y_op = r_orb * sin(nu);
ci = cosd(inc); si = sind(inc);
cO = cosd(RAAN); sO = sind(RAAN);
x_eci = cO*x_op - sO*ci*y_op;
y_eci = sO*x_op + cO*ci*y_op;
z_eci = si*y_op;

%% --- Shadow Check (vectorized 3D) ---
sunlit_flag = ~(x_eci < 0 & (y_eci.^2 + z_eci.^2) < Re^2);

%% --- 2D Projection ---
x = x_eci;  y = y_eci;

%% --- Earth Circle ---
theta_E = linspace(0, 2*pi, 500);
xE = Re * cos(theta_E);
yE = Re * sin(theta_E);

%% --- Preallocate ---
E_total    = zeros(1, N);
P_solar    = zeros(1, N);
P_albedo   = zeros(1, N);
P_earthIR  = zeros(1, N);
P_radiated = zeros(1, N);
P_internal = zeros(1, N);
P_elec     = zeros(1, N);
P_net      = zeros(1, N);
T_sat      = zeros(1, N);
lat_sat    = zeros(1, N);
time_in_sun = 0;

%% ====== PHYSICS LOOP ======
T = T_init;
E = 0;

for k = 1:N
    r_vec = [x_eci(k); y_eci(k); z_eci(k)];
    r_mag = norm(r_vec);
    r_hat = r_vec / r_mag;

    lat_sat(k) = asind(z_eci(k) / r_mag);
    w = min(abs(lat_sat(k)) / 60, 1);
    albedo_local  = albedo_eq*(1-w) + albedo_pol*w;
    T_earth_local = T_earth_eq*(1-w) + T_earth_pol*w;

    cos_sun = max(dot(r_hat, sun_ecliptic), 0);

    if sunlit_flag(k)
        P_solar(k)  = alpha_abs * A_sun * S_solar * cos_sun;
        P_albedo(k) = alpha_abs * A_earth * S_solar * albedo_local * F_earth;
        P_elec(k)   = eta_solar * A_panel * S_solar * cos_sun;
        time_in_sun = time_in_sun + dt;
    end

    P_earthIR(k)  = epsilon_ir * sigma * T_earth_local^4 * A_earth * F_earth;
    P_radiated(k) = epsilon_ir * sigma * T^4 * A_total;
    P_internal(k) = Q_internal;

    P_net(k) = P_solar(k) + P_albedo(k) + P_earthIR(k) + P_internal(k) ...
               - P_radiated(k) - P_elec(k);
    T = T + P_net(k) * dt / (sat_mass * sat_Cp);
    T_sat(k) = T;

    E = E + (P_solar(k) + P_albedo(k) + P_earthIR(k) + P_internal(k)) * dt;
    E_total(k) = E;
end

T_sat_C = T_sat - 273.15;
T_min_C = min(T_sat_C);
T_max_C = max(T_sat_C);
T_avg_C = mean(T_sat_C);

last_orbit_mask = t >= (NUM_ORBITS - 1) * Period;
T_last = T_sat_C(last_orbit_mask);
T_eq_amplitude = (max(T_last) - min(T_last)) / 2;
T_eq_mean = mean(T_last);
equil_reached = (NUM_ORBITS >= 2) && (T_eq_amplitude < 5);

%% --- Per-face temperature estimate (simplified) ---
% Sun face gets direct solar, anti-sun face is shaded, +/-Y and +/-Z are side faces.
% This is a rough 1st-order estimate for the heatmap schematic.
T_face = struct();
T_face.sun   = T_avg_C + 15;   % Hottest face (sun-facing)
T_face.anti  = T_avg_C - 20;   % Coldest face (anti-sun, deep space)
T_face.nadir = T_avg_C + 5;    % Earth-facing, gets IR
T_face.zenith = T_avg_C - 10;  % Space-facing
T_face.side1  = T_avg_C;       % Lateral faces near average
T_face.side2  = T_avg_C;

%% --- Frame indices ---
frame_idx = 1:SPEED_MULT:N;
N_frames  = length(frame_idx);

%% ====== MAIN FIGURE (Animation) ======
fig = figure('Position', [50 50 1280 720], 'Color', 'k', 'Renderer', 'opengl');
set(fig, 'Resize', 'off');

ax_orbit = subplot(2, 3, [1 2 4 5]);
set(ax_orbit, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
hold on; axis equal; grid on;
set(ax_orbit, 'GridColor', [0.3 0.3 0.3]);
title(sprintf('3U CubeSat  %d km  i=%+d deg  beta=%+.1f deg', ...
    round(alt/1e3), inc, beta_deg), 'Color', 'w', 'FontSize', 13);
xlabel('x_{ECI} [m]', 'Color', 'w');
ylabel('y_{ECI} [m]', 'Color', 'w');

% Shadow cones
shL = Re*3; tap = 0.3; shLp = Re*3.2; tapp = 0.15;
fill([0 -shL -shL 0 0], [Re Re*(1-tap) -Re*(1-tap) -Re Re], ...
    [0.15 0.15 0.15], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
fill([0 -shLp -shLp 0 0], [Re Re*(1-tapp) -Re*(1-tapp) -Re Re], ...
    [0.4 0.4 0.4], 'FaceAlpha', 0.3, 'EdgeColor', 'none');

plot(x, y, 'Color', [0.4 0.4 0.4], 'LineStyle', ':');
fill(xE, yE, [0.15 0.4 0.8], 'EdgeColor', [0.3 0.6 1], 'LineWidth', 1.5);

% Sun indicator
sun_x = r_orb * 1.15;
plot(sun_x, 0, 'o', 'MarkerSize', 20, 'MarkerFaceColor', [1 0.9 0.2], ...
    'MarkerEdgeColor', [1 0.7 0], 'LineWidth', 2);
for ra = linspace(0, 2*pi, 13)
    rs = r_orb*1.20; rl = r_orb*0.06;
    plot([rs*cos(ra), (rs+rl)*cos(ra)], [rs*sin(ra), (rs+rl)*sin(ra)], ...
        '-', 'Color', [1 0.85 0.1], 'LineWidth', 1.5);
end
text(sun_x, -r_orb*0.11, 'SUN', 'Color', [1 0.9 0.3], 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Trail
trail = scatter(x(1), y(1), 10, T_sat_C(1), 'filled');
caxis([T_min_C - 1, T_max_C + 1]);
colormap(ax_orbit, turbo(256));
cb = colorbar('Color', 'w', 'Location', 'southoutside');
cb.Label.String = 'Temperature [deg C]';
cb.Label.Color = 'w';

% Satellite marker
sat_c_sun = [1 0.3 0.1]; sat_c_shd = [0.3 0.3 0.4];
sat = plot(x(1), y(1), 'o', 'MarkerSize', 12, ...
    'MarkerFaceColor', sat_c_sun, 'MarkerEdgeColor', 'w', 'LineWidth', 1);

% HUD
hx1 = -0.95*r_orb; hx2 = 0.50*r_orb;
E_text      = text(hx1,  0.95*r_orb, '', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'w');
P_text      = text(hx1,  0.87*r_orb, '', 'FontSize', 10, 'Color', 'y');
T_text      = text(hx1,  0.79*r_orb, '', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [1 0.5 0.3]);
status_text = text(hx1,  0.71*r_orb, '', 'FontSize', 10, 'Color', [1 0.9 0.2]);
lat_text    = text(hx1,  0.63*r_orb, '', 'FontSize', 10, 'Color', [0.6 0.8 1]);
orbit_text  = text(hx2,  0.95*r_orb, '', 'FontSize', 10, 'Color', 'w');
time_text   = text(hx2,  0.87*r_orb, '', 'FontSize', 10, 'Color', [0.7 0.7 0.7]);
text(hx2, 0.79*r_orb, sprintf('beta=%+.1f deg', beta_deg), ...
    'FontSize', 10, 'Color', [0.5 1 0.5]);
minmax_text = text(hx1, -0.92*r_orb, '', 'FontSize', 9, 'Color', [0.8 0.8 0.8]);

% Right: Temperature subplot
ax_temp = subplot(2, 3, 3);
set(ax_temp, 'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w');
hold on; grid on; set(ax_temp, 'GridColor', [0.3 0.3 0.3]);
title('Temperature', 'Color', 'w', 'FontSize', 11);
xlabel('Time [min]', 'Color', 'w'); ylabel('T [deg C]', 'Color', 'w');
temp_line = plot(t(1)/60, T_sat_C(1), '-', 'Color', [1 0.4 0.2], 'LineWidth', 1.5);
xlim([0 NUM_ORBITS*Period/60]);

% Right: Energy subplot
ax_energy = subplot(2, 3, 6);
set(ax_energy, 'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w');
hold on; grid on; set(ax_energy, 'GridColor', [0.3 0.3 0.3]);
title('Cumulative Energy Absorbed', 'Color', 'w', 'FontSize', 11);
xlabel('Time [min]', 'Color', 'w'); ylabel('E [J]', 'Color', 'w');
energy_line = plot(t(1)/60, E_total(1), '-', 'Color', [0.3 0.8 1], 'LineWidth', 1.5);
xlim([0 NUM_ORBITS*Period/60]);

%% --- Video Writer ---
if EXPORT_VIDEO
    vidObj = VideoWriter('satellite_thermal_animation.mp4', 'MPEG-4');
    vidObj.FrameRate = VIDEO_FPS;
    vidObj.Quality = 95;
    open(vidObj);
end
drawnow;
if EXPORT_VIDEO
    test_frame = getframe(fig);
    expected_size = size(test_frame.cdata);
end

%% ====== ANIMATION LOOP ======
fprintf('Rendering %d frames (%d orbits, %dx speed)...    ', N_frames, NUM_ORBITS, SPEED_MULT);
prog_step = max(1, round(N_frames/50));

for fi = 1:N_frames
    k = frame_idx(fi);
    set(trail, 'XData', x(1:k), 'YData', y(1:k), 'CData', T_sat_C(1:k));
    set(sat, 'XData', x(k), 'YData', y(k));
    if sunlit_flag(k)
        set(sat, 'MarkerFaceColor', sat_c_sun);
    else
        set(sat, 'MarkerFaceColor', sat_c_shd);
    end

    cur_orbit = floor(t(k)/Period) + 1;
    set(E_text,      'String', sprintf('Energy = %.1f J', E_total(k)));
    set(P_text,      'String', sprintf('P_net = %+.2f W', P_net(k)));
    set(T_text,      'String', sprintf('T = %.1f deg C', T_sat_C(k)));
    set(orbit_text,  'String', sprintf('Orbit %d / %d', cur_orbit, NUM_ORBITS));
    set(time_text,   'String', sprintf('t = %.0f s  (%.1f min)', t(k), t(k)/60));
    set(lat_text,    'String', sprintf('Lat = %+.1f deg', lat_sat(k)));
    if sunlit_flag(k)
        set(status_text, 'String', 'SUNLIT', 'Color', [1 0.9 0.2]);
    else
        set(status_text, 'String', 'ECLIPSE', 'Color', [0.4 0.4 0.6]);
    end
    set(minmax_text, 'String', sprintf('Tmin=%.1f  Tmax=%.1f  Tavg=%.1f [deg C]', ...
        min(T_sat_C(1:k)), max(T_sat_C(1:k)), mean(T_sat_C(1:k))));

    set(temp_line,   'XData', t(1:k)/60, 'YData', T_sat_C(1:k));
    set(energy_line, 'XData', t(1:k)/60, 'YData', E_total(1:k));

    drawnow;

    if EXPORT_VIDEO
        frame = getframe(fig);
        if ~isequal(size(frame.cdata), expected_size)
            frame.cdata = imresize(frame.cdata, [expected_size(1) expected_size(2)]);
        end
        writeVideo(vidObj, frame);
    end

    if mod(fi, prog_step) == 0 || fi == N_frames
        fprintf('\b\b\b\b%3d%%', round(100*fi/N_frames));
    end
end
fprintf('  Done.\n');

if EXPORT_VIDEO
    close(vidObj);
end

%% ====== POST-SIMULATION FIGURES ======

% --- (11) 3D Orbit Visualization ---
fig3d = figure('Position', [100 100 800 700], 'Color', 'k');
ax3 = axes('Color', 'k', 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');
hold on; grid on; axis equal;
set(ax3, 'GridColor', [0.3 0.3 0.3]);

[sx, sy, sz] = sphere(40);
surf(Re*sx, Re*sy, Re*sz, 'FaceColor', [0.15 0.4 0.8], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.8);

scatter3(x_eci, y_eci, z_eci, 4, T_sat_C, 'filled');
caxis([T_min_C-1, T_max_C+1]);
colormap(ax3, turbo(256));
cb3 = colorbar('Color', 'w');
cb3.Label.String = 'Temperature [deg C]';
cb3.Label.Color = 'w';

plot3(x_eci(1), y_eci(1), z_eci(1), 'go', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'g', 'DisplayName', 'Start');
plot3(x_eci(end), y_eci(end), z_eci(end), 'rs', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'r', 'DisplayName', 'End');

quiver3(0, 0, 0, r_orb*1.3, 0, 0, 0, 'Color', [1 0.9 0.2], 'LineWidth', 2);
text(r_orb*1.35, 0, 0, 'Sun', 'Color', [1 0.9 0.3], 'FontSize', 11);

title(sprintf('3D Orbit  i=%+d deg  alt=%d km', inc, round(alt/1e3)), ...
    'Color', 'w', 'FontSize', 14);
xlabel('X [m]', 'Color', 'w');
ylabel('Y [m]', 'Color', 'w');
zlabel('Z [m]', 'Color', 'w');
legend('TextColor', 'w', 'Color', [0.15 0.15 0.15], 'Location', 'northeast');
view(135, 25);

% --- (13) CubeSat Thermal Heatmap (unfolded schematic) ---
fig_hm = figure('Position', [150 150 700 400], 'Color', 'k');
ax_hm = axes('Color', 'k');
hold on; axis equal off;

face_names  = {'+X (Sun)', '-X (Anti)', '+Y (Side)', '-Y (Side)', '+Z (Zenith)', '-Z (Nadir)'};
face_temps  = [T_face.sun, T_face.anti, T_face.side1, T_face.side2, T_face.zenith, T_face.nadir];
face_x      = [1, 3, 0, 4, 1, 1];
face_y      = [1, 1, 1, 1, 2, 0];

cmap_hm = turbo(256);
t_range = [min(face_temps)-5, max(face_temps)+5];

for f = 1:6
    ci_idx = round(1 + 255 * (face_temps(f) - t_range(1)) / (t_range(2) - t_range(1)));
    ci_idx = max(1, min(256, ci_idx));
    fc = cmap_hm(ci_idx, :);
    rectangle('Position', [face_x(f), face_y(f), 0.9, 0.9], ...
        'FaceColor', fc, 'EdgeColor', 'w', 'LineWidth', 1.5, ...
        'Curvature', 0.05);
    text(face_x(f)+0.45, face_y(f)+0.55, face_names{f}, ...
        'Color', 'w', 'FontSize', 9, 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold');
    text(face_x(f)+0.45, face_y(f)+0.3, sprintf('%.1f deg C', face_temps(f)), ...
        'Color', 'w', 'FontSize', 10, 'HorizontalAlignment', 'center');
end

colormap(ax_hm, turbo(256));
caxis(t_range);
cb_hm = colorbar('Color', 'w');
cb_hm.Label.String = 'Temperature [deg C]';
cb_hm.Label.Color = 'w';
title('3U CubeSat Face Temperatures (Orbit Average)', 'Color', 'w', 'FontSize', 13);

% --- (15) Power Breakdown Pie Chart ---
avg_P_solar    = mean(P_solar);
avg_P_albedo   = mean(P_albedo);
avg_P_earthIR  = mean(P_earthIR);
avg_P_internal = mean(P_internal);
avg_P_radiated = mean(P_radiated);
avg_P_elec     = mean(P_elec);

fig_pie = figure('Position', [200 200 700 500], 'Color', 'k');

% Heat inputs
subplot(1, 2, 1);
vals_in = [avg_P_solar, avg_P_albedo, avg_P_earthIR, avg_P_internal];
lbls_in = {sprintf('Solar\n%.3f W', avg_P_solar), ...
            sprintf('Albedo\n%.3f W', avg_P_albedo), ...
            sprintf('Earth IR\n%.3f W', avg_P_earthIR), ...
            sprintf('Internal\n%.3f W', avg_P_internal)};
pie(max(vals_in, 1e-6), lbls_in);
title('Heat Inputs (avg)', 'Color', 'w', 'FontSize', 12);
set(findobj(gca, 'Type', 'Text'), 'Color', 'w', 'FontSize', 9);

% Heat outputs
subplot(1, 2, 2);
vals_out = [avg_P_radiated, avg_P_elec];
lbls_out = {sprintf('Radiated\n%.3f W', avg_P_radiated), ...
             sprintf('Electrical\n%.3f W', avg_P_elec)};
pie(max(vals_out, 1e-6), lbls_out);
title('Heat Outputs (avg)', 'Color', 'w', 'FontSize', 12);
set(findobj(gca, 'Type', 'Text'), 'Color', 'w', 'FontSize', 9);

sgtitle('Power Budget Breakdown', 'Color', 'w', 'FontSize', 14);

%% ====== CONSOLE SUMMARY ======
fprintf('\n============ Simulation Summary ============\n');
fprintf('Spacecraft:             3U CubeSat (%.0f x %.0f x %.0f cm)\n', L1*100, L2*100, L3*100);
fprintf('Mass:                   %.1f kg\n', sat_mass);
fprintf('Solar absorptivity:     %.2f\n', alpha_abs);
fprintf('IR emissivity:          %.2f\n', epsilon_ir);
fprintf('A_sun:                  %.4f m^2\n', A_sun);
fprintf('A_earth:                %.4f m^2\n', A_earth);
fprintf('A_total:                %.4f m^2\n', A_total);
fprintf('--------------------------------------------\n');
fprintf('Internal heat:          %.2f W\n', Q_internal);
fprintf('  OBC:     %.2f W\n', Q_obc);
fprintf('  Radio:   %.2f W\n', Q_radio);
fprintf('  ADCS:    %.2f W\n', Q_adcs);
fprintf('  Payload: %.2f W\n', Q_payload);
fprintf('  EPS:     %.2f W\n', Q_eps);
fprintf('  Heater:  %.2f W\n', Q_heater);
fprintf('Solar panel eff:        %.1f%%\n', 100*eta_solar);
fprintf('Max elec. power:        %.2f W\n', eta_solar * S_solar * A_panel);
fprintf('--------------------------------------------\n');
fprintf('Orbits simulated:       %d\n', NUM_ORBITS);
fprintf('Altitude:               %.0f km\n', alt/1e3);
fprintf('Inclination:            %+d deg\n', inc);
fprintf('Beta angle:             %+.1f deg\n', beta_deg);
fprintf('Period:                 %.1f min\n', Period/60);
fprintf('Velocity:               %.1f m/s\n', v_orb);
fprintf('View factor:            %.4f\n', F_earth);
fprintf('Eclipse fraction:       %.1f%%\n', 100*eclipse_fraction);
fprintf('--------------------------------------------\n');
fprintf('Temperature (final):    %.1f deg C  (%.1f K)\n', T_sat_C(end), T_sat(end));
fprintf('Temperature (min):      %.1f deg C\n', T_min_C);
fprintf('Temperature (max):      %.1f deg C\n', T_max_C);
fprintf('Temperature (avg):      %.1f deg C\n', T_avg_C);
fprintf('Swing (last orbit):     +/-%.1f deg C around %.1f deg C\n', T_eq_amplitude, T_eq_mean);
if equil_reached
    fprintf('Equilibrium:            REACHED\n');
else
    fprintf('Equilibrium:            NOT YET\n');
end
fprintf('--------------------------------------------\n');
fprintf('Orbital lifetime:       ~%.1f years (%.0f days)\n', lifetime_years, lifetime_days);
fprintf('Ballistic coeff:        %.1f kg/m^2\n', BC);
fprintf('Atm. density (400km):   %.2e kg/m^3\n', rho_atm);
fprintf('--------------------------------------------\n');
fprintf('Total energy absorbed:  %.1f J\n', E_total(end));
fprintf('Avg absorbed power:     %.3f W\n', E_total(end)/(NUM_ORBITS*Period));
if EXPORT_VIDEO
    fprintf('Video:                  satellite_thermal_animation.mp4\n');
end
fprintf('============================================\n');

%% ====== (20) MONTE CARLO PARAMETER SWEEP ======
if RUN_MONTECARLO
    fprintf('\nRunning Monte Carlo (%d runs)...    ', MC_RUNS);
    mc_T_final = zeros(1, MC_RUNS);
    mc_T_min   = zeros(1, MC_RUNS);
    mc_T_max   = zeros(1, MC_RUNS);

    alpha_nom = alpha_abs;  eps_nom = epsilon_ir;
    mass_nom  = sat_mass;   cp_nom  = sat_Cp;

    for mc = 1:MC_RUNS
        a_mc = alpha_nom * (1 + 0.10*(2*rand-1));
        e_mc = eps_nom   * (1 + 0.10*(2*rand-1));
        m_mc = mass_nom  * (1 + 0.05*(2*rand-1));
        c_mc = cp_nom    * (1 + 0.08*(2*rand-1));

        T_mc = T_init;
        T_hist = zeros(1, N);
        for k = 1:N
            r_vec_mc = [x_eci(k); y_eci(k); z_eci(k)];
            r_hat_mc = r_vec_mc / norm(r_vec_mc);
            lat_mc = abs(asind(z_eci(k) / norm(r_vec_mc)));
            w_mc = min(lat_mc/60, 1);
            alb_mc = albedo_eq*(1-w_mc) + albedo_pol*w_mc;
            Te_mc  = T_earth_eq*(1-w_mc) + T_earth_pol*w_mc;
            cs_mc  = max(dot(r_hat_mc, sun_ecliptic), 0);

            Ps = 0; Pa = 0; Pe = 0;
            if sunlit_flag(k)
                Ps = a_mc * A_sun * S_solar * cs_mc;
                Pa = a_mc * A_earth * S_solar * alb_mc * F_earth;
                Pe = eta_solar * A_panel * S_solar * cs_mc;
            end
            Pir  = e_mc * sigma * Te_mc^4 * A_earth * F_earth;
            Prad = e_mc * sigma * T_mc^4 * A_total;
            Pn   = Ps + Pa + Pir + Q_internal - Prad - Pe;
            T_mc = T_mc + Pn * dt / (m_mc * c_mc);
            T_hist(k) = T_mc;
        end
        mc_T_final(mc) = T_hist(end) - 273.15;
        mc_T_min(mc)   = min(T_hist) - 273.15;
        mc_T_max(mc)   = max(T_hist) - 273.15;

        if mod(mc, round(MC_RUNS/20)) == 0
            fprintf('\b\b\b\b%3d%%', round(100*mc/MC_RUNS));
        end
    end
    fprintf('  Done.\n');

    fig_mc = figure('Position', [250 250 900 400], 'Color', 'k');

    subplot(1, 3, 1);
    histogram(mc_T_final, 20, 'FaceColor', [0.3 0.8 1], 'EdgeColor', 'w');
    title('Final T', 'Color', 'w');
    xlabel('deg C', 'Color', 'w'); ylabel('Count', 'Color', 'w');
    set(gca, 'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w');

    subplot(1, 3, 2);
    histogram(mc_T_min, 20, 'FaceColor', [0.2 0.5 1], 'EdgeColor', 'w');
    title('Min T', 'Color', 'w');
    xlabel('deg C', 'Color', 'w'); ylabel('Count', 'Color', 'w');
    set(gca, 'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w');

    subplot(1, 3, 3);
    histogram(mc_T_max, 20, 'FaceColor', [1 0.4 0.2], 'EdgeColor', 'w');
    title('Max T', 'Color', 'w');
    xlabel('deg C', 'Color', 'w'); ylabel('Count', 'Color', 'w');
    set(gca, 'Color', [0.05 0.05 0.05], 'XColor', 'w', 'YColor', 'w');

    sgtitle('Monte Carlo Temperature Distribution', 'Color', 'w', 'FontSize', 14);

    fprintf('\n--- Monte Carlo Results (%d runs) ---\n', MC_RUNS);
    fprintf('Final T:  mean=%.1f  std=%.1f  [%.1f, %.1f] deg C\n', ...
        mean(mc_T_final), std(mc_T_final), min(mc_T_final), max(mc_T_final));
    fprintf('Min T:    mean=%.1f  std=%.1f  [%.1f, %.1f] deg C\n', ...
        mean(mc_T_min), std(mc_T_min), min(mc_T_min), max(mc_T_min));
    fprintf('Max T:    mean=%.1f  std=%.1f  [%.1f, %.1f] deg C\n', ...
        mean(mc_T_max), std(mc_T_max), min(mc_T_max), max(mc_T_max));
    fprintf('alpha:    %.2f +/- 10%%\n', alpha_nom);
    fprintf('epsilon:  %.2f +/- 10%%\n', eps_nom);
    fprintf('mass:     %.2f +/- 5%%\n', mass_nom);
    fprintf('Cp:       %.0f +/- 8%%\n', cp_nom);
end

%% --- Helper function (avoids forward-reference issues) ---
function val = S_solar_val()
    val = 1361;
end
