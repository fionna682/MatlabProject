function out = ThermalModel(C1, C2, Rr, Rw, Q, To, Tr0, Tw0, Tend)

A = [-1/(Rr*C1),  1/(Rr*C1);
    1/(Rr*C2), -(1/Rr + 1/Rw)/C2];

B = [1/C1, 0;
    0,    1/(Rw*C2)];

sys = ss(A, B, eye(2), zeros(2));

t = linspace(0, Tend, 1000)';
u = [Q*ones(size(t)), To*ones(size(t))];

y = lsim(sys, u, t, [Tr0; Tw0]);

out.t = t;
out.Tr = y(:,1);
out.Tw = y(:,2);

out.Tr_ss = To + Q*(Rr + Rw);
out.Tw_ss = To + Q*Rw;

out.lambda = sort(eig(A), 'descend');
out.tau = -1 ./ out.lambda;

end