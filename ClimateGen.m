% -----------------------------------------------------------------
% ClimateGen.m
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr
%               americo.cunhajr@gmail.com
%               
%               Christian Soize
%               christian.soize@univ-eiffel.fr
%
%  Originally programmed in: Feb 14, 2025
%            Last update in: Jul 11, 2025
% -----------------------------------------------------------------
% This function generates a synthetic time‐series for a climate 
% variable by decomposing into:
% 
%   * baselineSeries – trend + seasonal skeleton (low‐pass)
%   * residuals      – high‐frequency fluctuations
% 
% It then simulates new residuals and reconstructs:
%   1. Build seasonalProfile by window‐averaging baselineSeries
%   2. Log‐transform origSeries, baselineSeries and seasonalProfile
%   3. Extract and center logResiduals
%   4. Simulate syntheticResiduals via GaussianGen
%   5. Reconstruct logSyntheticSeries
%   6. Exponentiate to obtain syntheticSeries
%
% Input:
%   (double N x 1) origSeries      – original data series
%   (double N x 1) baselineSeries  – filtered trend+seasonal series
%   (int >0)       winLen          – window length for seasonalProfile
%   (int >0)       stride          – step size for residual sampling
%   (int >0)       nSamp           – samples per synthetic realization
%   (int >0)       nReal           – number of synthetic realizations
%
% Output:
%   (double winLen x nReal) syntheticSeries – synthetic data series
% -----------------------------------------------------------------
function syntheticSeries = ClimateGen(origSeries,baselineSeries, ...
                                      winLen,stride,nSamp,nReal)

    % check number of arguments
    if nargin < 6
        error('Too few inputs.');
    elseif nargin > 6
        error('Too many inputs.');
    end

    % check for consistency
    if ~isnumeric(origSeries) || ~isvector(origSeries)
        error('origSeries must be a numeric vector.');
    end
    if ~isnumeric(baselineSeries) || ~isvector(baselineSeries)
        error('baselineSeries must be a numeric vector.');
    end
    if numel(origSeries)~=numel(baselineSeries)
        error('origSeries and baselineSeries must match length.');
    end
    if ~isscalar(winLen) || winLen<=0 || mod(winLen,1)~=0
        error('winLen must be a positive integer.');
    end
    if ~isscalar(stride) || stride<=0 || mod(stride,1)~=0
        error('stride must be a positive integer.');
    end
    if ~isscalar(nSamp) || nSamp<=0 || mod(nSamp,1)~=0
        error('nSamp must be a positive integer.');
    end
    if ~isscalar(nReal) || nReal<=0 || mod(nReal,1)~=0
        error('nReal must be a positive integer.');
    end
    if mod(numel(baselineSeries),winLen) ~= 0
        error('baselineSeries length must be a multiple of winLen.');
    end

    % build seasonal skeleton from baseline
    % -- baseline is reshaped into winLen×(N/winLen), average each row --
    seasonalProfile = mean(reshape(baselineSeries,winLen,[]),2);

    % log‐transform
    logOrig     = log(origSeries);
    logBaseline = log(baselineSeries);
    logSeasonal = log(seasonalProfile);

    % extract and center log‐residuals
    logResiduals      = logOrig - logBaseline;
    meanResidual      = mean(logResiduals);
    residualsCentered = logResiduals - meanResidual;

    % simulate synthetic residuals
    syntheticResiduals = GaussianGen(residualsCentered,stride,nSamp,nReal);

    % reconstruct log‐series (winLen×nReal)
    logSyntheticSeries = logSeasonal + meanResidual + syntheticResiduals;

    % exponentiate to original scale
    syntheticSeries = exp(logSyntheticSeries);
end
% -----------------------------------------------------------------