%% Visualization of a room heating up - but with diffusivity
clc ; clear ; close all ;


%% Raum
Lx = 10; Ly = 10;                 % Breite, Höhe in m
dx = 0.1;
nx = round(Lx/dx); ny = round(Ly/dx);

alpha = 0.01;                   % effektive Diffusivität in m²/s (siehe Hinweis)
dt    = 0.2*dx^2/alpha;         % Stabilitätsbedingung dt <= dx²/(4*alpha) erfüllt
To  = 3;  Tr0 = 8;  Tw0 = 4; Theiz = 50;
kLoss = 0.01;                  % Verlustrate an den Wänden in 1/s

T = Tr0*ones(ny,nx);          % Zeile = y (unten = 1), Spalte = x

heater = false(ny,nx);  heater(ny/2-2:ny/2+2, nx/2-2:nx/2+2) = true;    % Heizkörper rechts unten
wall = false(ny,nx);
wall(:, 1) = true;    % Wand links
wall(:, end) = true;    % Wand rechts
wall(end, :) = true;    % Wand oben

T(wall) = Tw0;


%% Simulation + Animation
[x,y] = meshgrid((1:nx)*dx, (1:ny)*dx);
figure
hImg = imagesc(x(1,:), y(:,1), T);  axis xy equal tight
colormap(turbo); clim([To 30]); cb = colorbar; cb.Label.String = 'T in °C';
xlabel('x in m'); ylabel('y in m')

stepsPerFrame = 100;  nFrames = 300;
t = 0;
for f = 1:nFrames
    for s = 1:stepsPerFrame
        % Nachbarn mit gespiegeltem Rand (adiabate Wand)
        Tn = T([1 1:end-1],:);   Ts = T([2:end end],:);
        Tw = T(:,[1 1:end-1]);   Te = T(:,[2:end end]);
        lap = (Tn + Ts + Tw + Te - 4*T)/dx^2;

        T = T + dt*alpha*lap;
        T(wall) = T(wall) - dt*kLoss*(T(wall) - To);
        T(heater) = Theiz;
        t = t + dt;
    end
    hImg.CData = T;
    title(sprintf('t = %.1f min,  Mittel = %.1f °C', t/60, mean(T(:))))
    drawnow
end


%% New Version without diffusivity

clc; clear; close all


%% Parameter
C1 = 0.5; C2 = 1.5; Rr = 0.5; Rw = 1.8;
Q = 5; To = 3; Tr0 = 8; Tw0 = 4;

% out  = ThermalModel(C1, C2, Rr, Rw, Q, To, Tr0, Tw0, 5*3.7);   % Tend ca. 5*tau_max, siehe unten
% Tend = 5*max(out.tau);
Tend = 30;
out  = ThermalModel(C1, C2, Rr, Rw, Q, To, Tr0, Tw0, Tend);

t = out.t;  Tr = out.Tr;  Tw = out.Tw;

% Wärmeströme
Q_heat = Q*ones(size(t));
Q_rw   = (Tr - Tw)/Rr;          % Raum -> Wand
Q_wo   = (Tw - To)/Rw;          % Wand -> Außen

Tmin = min([Tr; Tw; To]) - 1;
Tmax = max([out.Tr_ss out.Tw_ss To]) + 1;

%% Figure
fig = figure('Color','w','Position',[100 100 1100 600]);
tl  = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

% --- 1) Schnittschema ---
ax1 = nexttile(1,[2 1]);  hold(ax1,'on');
xs = [0 1 2 5];                         % Außen | Wand | Raum
zones = {[xs(1) xs(2)], [xs(2) xs(3)], [xs(3) xs(4)]};
hP = gobjects(1,3);
for k = 1:3
    x0 = zones{k}(1); x1 = zones{k}(2);
    hP(k) = patch(ax1,[x0 x1 x1 x0],[0 0 3 3],To,'EdgeColor','k','LineWidth',1.5);
end
patch(ax1,[4.6 4.9 4.9 4.6],[0.3 0.3 1.3 1.3],[0.4 0.4 0.4]);   % Heizkörper
text(ax1,4.75,1.45,'Heizung','HorizontalAlignment','center','FontSize',9)
txt = {'Außen','Wand','Raum'};
for k = 1:3
    text(ax1,mean(zones{k}),2.75,txt{k},'HorizontalAlignment','center','FontWeight','bold');
end
hT = gobjects(1,3);
for k = 1:3
    hT(k) = text(ax1,mean(zones{k}),1.5,'','HorizontalAlignment','center', ...
        'FontSize',12,'FontWeight','bold','BackgroundColor',[1 1 1 0.7]);
end
colormap(ax1,turbo); clim(ax1,[Tmin Tmax]);
cb = colorbar(ax1); cb.Label.String = 'T in °C';
axis(ax1,'equal','off'); xlim(ax1,[-0.1 5.1]); ylim(ax1,[-0.1 3.1]);
hTitle = title(ax1,'');

% --- 2) Temperaturverläufe ---
ax2 = nexttile(2); hold(ax2,'on'); grid(ax2,'on')
plot(ax2,t,Tr,'r','LineWidth',2);
plot(ax2,t,Tw,'b','LineWidth',2);
yline(ax2,To,'k-.','T_{außen}');
yline(ax2,out.Tr_ss,'r:','T_{R,ss}');
yline(ax2,out.Tw_ss,'b:','T_{W,ss}');
xline(ax2,out.tau(1),'--','\tau_1 = '+string(round(out.tau(1),2)),'Color',[.4 .4 .4]);
xline(ax2,out.tau(2),'--','\tau_2 = '+string(round(out.tau(2),2)),'Color',[.4 .4 .4]);
hM2 = xline(ax2,0,'k','LineWidth',1.5);
legend(ax2,{'Raum T_R','Wand T_W'},'Location','east')
xlabel(ax2,'t'); ylabel(ax2,'T in °C'); title(ax2,'Temperaturverlauf')

% --- 3) Wärmeströme ---
ax3 = nexttile(4); hold(ax3,'on'); grid(ax3,'on')
plot(ax3,t,Q_heat,'Color',[.85 .33 .1],'LineWidth',2);
plot(ax3,t,Q_rw,'Color',[.5 0 .5],'LineWidth',2);
plot(ax3,t,Q_wo,'Color',[0 .45 .74],'LineWidth',2);
hM3 = xline(ax3,0,'k','LineWidth',1.5);
legend(ax3,{'Heizung → Raum','Raum → Wand','Wand → Außen'},'Location','east')
xlabel(ax3,'t'); ylabel(ax3,'Q̇'); title(ax3,'Wärmeströme')

%% Animation
frames = round(linspace(1,numel(t),200));
for i = frames
    Tvals = [To, Tw(i), Tr(i)];
    for k = 1:3
        hP(k).FaceColor = 'flat';  hP(k).CData = Tvals(k);
        hT(k).String = sprintf('%.1f °C',Tvals(k));
    end
    hM2.Value = t(i);  hM3.Value = t(i);
    hTitle.String = sprintf('t = %.2f',t(i));
    drawnow
end