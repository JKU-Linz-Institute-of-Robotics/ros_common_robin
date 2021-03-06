function [ res ] = get_spl_fun( spl )
%get_spl_fun Returns a Casadi function for the given spline
% Input:    spl: spline (generated by bst)
% Output:   res: casadi function
% 
% The resulting Casadi function provides the following interface
% Input:    parr: scalar parameter at which the spline is evaluated
%           der: scara order of derivative (0 means no derivative)
%           ctrl_pts: row vector of control points
%           par_start, par_end: start and end parameters
% Output:   value of spline
%

import casadi.*

EPS = 1e-8;
fmt = '%.10f';

% function inputs
parr = SX.sym('parr');
der = SX.sym('der');
par_start = SX.sym('par_start');
par_end = SX.sym('par_end');
ctrl_pts = SX.sym('ctrl_pts', size(spl.ctrl_pts));

% saturate parameter in admissible range
% par = if_else(parr < par_start, par_start, ...
%         if_else(parr > par_end, par_end, parr));
    par = parr;
% normalize parameter
par = (par - par_start)/(par_end - par_start);

% compute vector of unique knots
unique_knots = spl.knots;
knots_diff = diff(unique_knots);
while(min(knots_diff) < EPS)
    unique_knots(knots_diff < EPS) = [];
    knots_diff = diff(unique_knots);
end

% precompute vector of powers of parameter
pow_vec0 = par^(spl.degree:-1:0)';
exp_vec_cell = cell(spl.degree,1);
pow_vec_cell = cell(spl.degree,1);
for h = 1:spl.degree % all possible derivatives
    exp_vec = ones(spl.degree + 1,1);
    for i = 1:spl.degree + 1 % all entries of exp_vec
        for j = 0:h-1 % product
            exp_vec(i) = exp_vec(i)*(spl.degree - (i-1) - j);
        end
    end
    exp_vec(end-h+1) = 0; % set last (der) elements to zero
    exp_vec_cell{h} = exp_vec;
    
    pow_vec_cell{h} = [pow_vec0(h+1:end); zeros(h,1)];
end
pow_vec_str = 'if_else(der < 1, par^(spl.degree:-1:0)'', ';
for i = 1:spl.degree
    pow_vec_str = [pow_vec_str, 'if_else(der == ', num2str(i), ', pow_vec_cell{',num2str(i),'}, ']; 
end
pow_vec_str = [pow_vec_str, 'zeros(spl.degree+1,1)', repmat(')', [1, spl.degree+1])];
pow_vec = eval(pow_vec_str);

% matrix of coefficients
coeff_mat_str = [];
for i = 2:length(unique_knots)
    coeff_mat_str = [coeff_mat_str, ...
        'if_else(par < ',num2str(unique_knots(i),fmt),', spl.coeffs(:,:,',num2str(i-1),'), '];
end
coeff_mat_str = [coeff_mat_str, ...
    'spl.coeffs(:,:,end)', repmat(')',[1,length(unique_knots)-1])];
coeff_mat = eval(coeff_mat_str);

% precompute vector of exponent products
exp_vec_str = 'if_else(der < 1, ones(spl.degree+1,1), ';
for i = 1:spl.degree
    exp_vec_str = [exp_vec_str, 'if_else(der == ', num2str(i), ', exp_vec_cell{',num2str(i),'}, ']; 
end
exp_vec_str = [exp_vec_str, 'zeros(spl.degree+1,1)', repmat(')', [1, spl.degree+1])];
exp_vec = eval(exp_vec_str);

% evaluate spline
val = 1/(par_end - par_start)^der*ctrl_pts'*coeff_mat*(exp_vec.*pow_vec);

% function definition
res = Function('spl_fun', {parr, der, ctrl_pts, par_start, par_end}, {val});
end

