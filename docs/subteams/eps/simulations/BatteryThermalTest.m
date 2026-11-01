close all;

Cp = 950; % the specific heat capacity of the battery cell

T_initial = 20; % initial temperature of 20 degrees C

T_initial_air = 20; % ambient air temperature

Q_Source = 10; % heat source of 10W

mass = 0.065; % average mass of 65g

A = 0.0021; % battery surface area 

h = 10; % convective heat transfer coefficient

time = 0:1:550; % time interval of model

tau = (mass*Cp) / (h*A);
Steadystate_temp = T_initial_air +(Q_Source/(h * A));



T_ideal = T_initial + (Q_Source / (Cp * mass)) * time; 
hold on; % Retain current plot
xlabel('Time (s)');
ylabel('Temperature (°C)');
title('Battery Temperature Response');

T_real = Steadystate_temp +(T_initial - Steadystate_temp)*exp(-time/tau); 


plot(time, T_real, '--');
plot(time,T_ideal);
grid on;
