function ThermalApp()
% THERMALAPP  Room heating simulator (Project 1.2).
%   Run with:  ThermalApp
%   Needs GenerateProfile.m and ThermalModelTV.m in the same folder,
%   and the Control System Toolbox.

%% ---------- Window layout ----------
fig  = uifigure('Name', 'Room heating - thermal model', 'Position', [80 60 1250 780]);
main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {340, '1x'};

left = uigridlayout(main, [30 2]);          % controls (scrollable)
left.RowHeight = repmat({24}, 1, 30);
left.RowSpacing = 4;
left.Scrollable = 'on';

right = uigridlayout(main, [3 1]);          % plots + result labels
right.RowHeight = {'1x', '1x', 64};

axT = uiaxes(right);
title(axT, 'Room and wall temperature');
xlabel(axT, 't [s]'); ylabel(axT, 'Temperature [deg C]'); grid(axT, 'on');
axI = uiaxes(right);
title(axI, 'Input profiles');
xlabel(axI, 't [s]'); ylabel(axI, 'Q (heater) and To (deg C)'); grid(axI, 'on');
info = uilabel(right, 'Text', '', 'VerticalAlignment', 'top');

%% ---------- Controls ----------
row  = 0;
ctrl = {};          % {handle, default} pairs, used by Reset
runs = {};          % stored simulation results (for "hold previous runs")
lastOut = [];

addHeader('Parameters');
hC1  = addNum('C1 room capacity',   0.5);
hC2  = addNum('C2 wall capacity',   1.5);
hRr  = addNum('Rr room-wall resist.', 0.5);
hRw  = addNum('R wall-outside resist.', 1.8);
hTr0 = addNum('Initial Tr [deg C]', 8);
hTw0 = addNum('Initial Tw [deg C]', 4);
hEnd = addNum('Simulation time [s]', 30);

Qspecs = {'Level',  'Value / mean',      5;
          'Level2', 'Value after step',  8;
          'TStep',  'Step time [s]',     10;
          'Amp',    'Amplitude',         2;
          'Period', 'Period [s]',        10;
          'Hold',   'Hold time [s]',     1;
          'Seed',   'Random seed',       1};
Qblk = addBlock('Heater profile Q(t)', {'Constant','Step','Sinusoidal','Random'}, Qspecs);

Tspecs = {'Level',  'Mean [deg C]',      3;
          'Amp',    'Amplitude [deg C]', 2;
          'Period', 'Period, 1 day [s]', 24;
          'Hold',   'Hold time [s]',     1;
          'Seed',   'Random seed',       2};
Tblk = addBlock('Outside temperature To(t)', {'Constant','Daily sinusoid','Random around mean'}, Tspecs);

row = row + 1;
chkHold = uicheckbox(left, 'Text', 'Hold previous runs');
chkHold.Layout.Row = row; chkHold.Layout.Column = [1 2];
ctrl{end+1} = {chkHold, false};

row = row + 1;
bRun = uibutton(left, 'Text', 'Run simulation', 'ButtonPushedFcn', @onRun, 'FontWeight', 'bold');
bRun.Layout.Row = row; bRun.Layout.Column = 1;
bRes = uibutton(left, 'Text', 'Reset to defaults', 'ButtonPushedFcn', @onReset);
bRes.Layout.Row = row; bRes.Layout.Column = 2;

row = row + 1;
bCsv = uibutton(left, 'Text', 'Export CSV', 'ButtonPushedFcn', @onCsv);
bCsv.Layout.Row = row; bCsv.Layout.Column = 1;
bFig = uibutton(left, 'Text', 'Save figures', 'ButtonPushedFcn', @onFigs);
bFig.Layout.Row = row; bFig.Layout.Column = 2;

row = row + 1;
bHelp = uibutton(left, 'Text', 'Help', 'ButtonPushedFcn', @onHelp);
bHelp.Layout.Row = row; bHelp.Layout.Column = [1 2];

onRun([], []);      % show the default simulation at start-up

%% ---------- Helper functions to build the controls ----------
    function addHeader(txt)
        row = row + 1;
        l = uilabel(left, 'Text', txt, 'FontWeight', 'bold');
        l.Layout.Row = row; l.Layout.Column = [1 2];
    end

    function h = addNum(label, val)
        row = row + 1;
        l = uilabel(left, 'Text', label);
        l.Layout.Row = row; l.Layout.Column = 1;
        h = uieditfield(left, 'numeric', 'Value', val);
        h.Layout.Row = row; h.Layout.Column = 2;
        ctrl{end+1} = {h, val};
    end

    function blk = addBlock(titleTxt, types, specs)
        addHeader(titleTxt);
        row = row + 1;
        dd = uidropdown(left, 'Items', types, 'Value', types{1});
        dd.Layout.Row = row; dd.Layout.Column = [1 2];
        ctrl{end+1} = {dd, types{1}};
        blk.dd = dd;
        blk.f  = struct();
        for k = 1:size(specs, 1)
            blk.f.(specs{k,1}) = addNum(specs{k,2}, specs{k,3});
        end
        dd.ValueChangedFcn = @(~,~) updateEnable(blk);
        updateEnable(blk);
    end

    function updateEnable(blk)
        % Only the fields the selected profile uses are editable
        switch lower(blk.dd.Value)
            case 'constant',                     used = {'Level'};
            case 'step',                         used = {'Level','Level2','TStep'};
            case {'sinusoidal','daily sinusoid'}, used = {'Level','Amp','Period'};
            otherwise,                           used = {'Level','Amp','Hold','Seed'};
        end
        names = fieldnames(blk.f);
        for k = 1:numel(names)
            blk.f.(names{k}).Enable = ismember(names{k}, used);
        end
    end

    function cfg = makeCfg(blk)
        % Collect the settings of one profile block into a struct
        cfg.Type = blk.dd.Value;
        names = fieldnames(blk.f);
        for k = 1:numel(names)
            cfg.(names{k}) = blk.f.(names{k}).Value;
        end
        cfg.Mean = cfg.Level;                 % GenerateProfile uses .Mean for sin/random
        if isfield(cfg, 'Seed'), cfg.Seed = round(abs(cfg.Seed)); end
        t = lower(cfg.Type);
        if contains(t, 'sin') && cfg.Period <= 0
            error('The period must be positive.');
        end
        if contains(t, 'random') && cfg.Hold <= 0
            error('The hold time must be positive.');
        end
    end

%% ---------- Callbacks ----------
    function onRun(~, ~)
        try
            vals = [hC1.Value hC2.Value hRr.Value hRw.Value hEnd.Value];
            if any(vals <= 0)
                error('C1, C2, Rr, R and the simulation time must be positive.');
            end
            out = ThermalModelTV(hC1.Value, hC2.Value, hRr.Value, hRw.Value, ...
                  hTr0.Value, hTw0.Value, hEnd.Value, makeCfg(Qblk), makeCfg(Tblk));
        catch ME
            uialert(fig, ME.message, 'Could not run the simulation');
            return
        end
        if ~chkHold.Value, runs = {}; end
        runs{end+1} = out;
        lastOut = out;
        redraw();
        info.Text = { ...
            sprintf('Latest run - steady state (final/mean inputs): Tr = %.2f deg C,  Tw = %.2f deg C', out.Tr_ss, out.Tw_ss), ...
            sprintf('Time constants (tau = -1/lambda): slow = %.3f s,  fast = %.3f s', out.tau(1), out.tau(2))};
    end

    function redraw()
        cla(axT); cla(axI);
        hold(axT, 'on'); hold(axI, 'on');
        cols = lines(max(numel(runs), 1));
        for k = 1:numel(runs)
            o = runs{k};
            plot(axT, o.t, o.Tr, '-',  'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Run %d: Tr', k));
            plot(axT, o.t, o.Tw, '--', 'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Run %d: Tw', k));
            plot(axI, o.t, o.Q,  '-',  'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Run %d: Q', k));
            plot(axI, o.t, o.To, '--', 'Color', cols(k,:), 'LineWidth', 1.5, 'DisplayName', sprintf('Run %d: To', k));
        end
        legend(axT, 'Location', 'eastoutside');
        legend(axI, 'Location', 'eastoutside');
    end

    function onReset(~, ~)
        for k = 1:numel(ctrl)
            ctrl{k}{1}.Value = ctrl{k}{2};
        end
        updateEnable(Qblk); updateEnable(Tblk);
        runs = {}; lastOut = [];
        onRun([], []);
    end

    function onCsv(~, ~)
        if isempty(lastOut)
            uialert(fig, 'Run a simulation first.', 'Nothing to export'); return
        end
        [f, p] = uiputfile('*.csv', 'Export latest run', 'thermal_results.csv');
        if isequal(f, 0), return, end
        o = lastOut;
        T = table(o.t, o.Q, o.To, o.Tr, o.Tw, 'VariableNames', {'t_s','Q','To','Tr','Tw'});
        writetable(T, fullfile(p, f));
    end

    function onFigs(~, ~)
        if isempty(lastOut)
            uialert(fig, 'Run a simulation first.', 'Nothing to save'); return
        end
        [f, p] = uiputfile('*.png', 'Save figures', 'thermal_figure.png');
        if isequal(f, 0), return, end
        [~, name] = fileparts(f);
        exportgraphics(axT, fullfile(p, [name '_temperatures.png']), 'Resolution', 200);
        exportgraphics(axI, fullfile(p, [name '_inputs.png']),       'Resolution', 200);
    end

    function onHelp(~, ~)
        msg = { ...
            'Set the parameters and initial temperatures, pick one profile for the heater Q(t) and one for the outside temperature To(t), then press Run simulation.', ...
            ' ', ...
            'Only the fields that the chosen profile uses are editable. Step: value before / after and step time. Sinusoidal: mean, amplitude, period. Random: mean, amplitude, hold time (how long each random value lasts) and seed (same seed = same signal).', ...
            ' ', ...
            'Hold previous runs: keeps old curves in the plots so you can compare different R and C values. Solid lines = Tr and Q, dashed = Tw and To.', ...
            ' ', ...
            'Export CSV saves the latest run (t, Q, To, Tr, Tw). Save figures writes both plots as PNG files.'};
        uialert(fig, msg, 'Help', 'Icon', 'info');
    end
end
