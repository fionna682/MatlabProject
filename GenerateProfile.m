function [u, nominal] = GenerateProfile(type, t, p)
% GENERATEPROFILE  Build an input signal (heater Q(t) or outside temp To(t)).
%
%   [u, nominal] = GenerateProfile(type, t, p)
%
%   type : 'Constant' | 'Step' | 'Sinusoidal' | 'Random'
%          (for To also accepted: 'Daily sinusoid', 'Random around mean')
%   t    : time vector
%   p    : struct with the settings the chosen type needs:
%            Constant   : p.Level
%            Step       : p.Level (before), p.Level2 (after), p.TStep
%            Sinusoidal : p.Mean, p.Amp, p.Period
%            Random     : p.Mean, p.Amp, p.Hold (s per random value), p.Seed
%
%   u       : signal, same size as t (column)
%   nominal : the "typical" value (used for the steady-state labels)

t = t(:);
switch lower(type)
    case 'constant'
        u = p.Level * ones(size(t));
        nominal = p.Level;

    case 'step'
        u = p.Level * ones(size(t));
        u(t >= p.TStep) = p.Level2;
        nominal = p.Level2;                 % value after the step

    case {'sinusoidal', 'daily sinusoid'}
        u = p.Mean + p.Amp * sin(2*pi*t / p.Period);
        nominal = p.Mean;

    case {'random', 'random around mean'}
        % Own random stream: same seed -> same signal, and the global
        % random generator is left untouched.
        stream = RandStream('mt19937ar', 'Seed', p.Seed);
        nVals  = ceil(t(end) / p.Hold) + 1;
        vals   = p.Mean + p.Amp * randn(stream, nVals, 1);
        idx    = floor(t / p.Hold) + 1;     % hold each value for p.Hold seconds
        u = vals(idx);
        nominal = p.Mean;

    otherwise
        error('GenerateProfile:unknownType', 'Unknown profile type "%s".', type);
end
end
