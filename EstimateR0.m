% -----------------------------------------------------------------
% EstimateR0.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 29, 2026
%            Last update in: Jul 29, 2026
% -----------------------------------------------------------------
% Estimates a plausible range for r0 from prevalence curves.
%
% Input:
%   Cdata : nWeeks x nSeasons matrix of cumulative cases
%   q     : early-growth exponent
%
% Output:
%   r0_min   : robust lower bound
%   r0_max   : robust upper bound
%   r0_stats : diagnostic structure
% -----------------------------------------------------------------
function [r0_min,r0_max,r0_stats] = EstimateR0(Cdata,q)


if nargin < 2
    q = 1;
end

Cdata = max(real(Cdata),0);

[nWeeks,nSeasons] = size(Cdata);

r_pool = [];

for s = 1:nSeasons

    C = Cdata(:,s);

    if C(end) <= 0
        continue
    end

    % weekly increments
    dC = [C(1); diff(C)];
    dC = max(dC,0);

    % define early phase:
    % after outbreak starts and before 30% of final size
    Kobs = C(end);

    idx = find(C > 0.01*Kobs & C < 0.30*Kobs & dC > 0);

    if numel(idx) < 3
        continue
    end

    r_inst = dC(idx) ./ (C(idx).^q);

    r_inst = r_inst(isfinite(r_inst) & r_inst > 0);

    r_pool = [r_pool; r_inst(:)];
end

if isempty(r_pool)
    error('Could not estimate r0 range from prevalence data.');
end

% robust bounds
r0_min = prctile(r_pool,5);
r0_max = prctile(r_pool,95);

r0_stats.values = r_pool;
r0_stats.median = median(r_pool);
r0_stats.mean   = mean(r_pool);
r0_stats.std    = std(r_pool);
r0_stats.q05    = r0_min;
r0_stats.q95    = r0_max;

end
% -----------------------------------------------------------------