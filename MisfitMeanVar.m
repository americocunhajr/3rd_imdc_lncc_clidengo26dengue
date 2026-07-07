% -----------------------------------------------------------------
%  MisfitMeanVar.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%               
%  Initially Programmed: Jul 11, 2025
%           Last Update: Jul 17, 2025
% -----------------------------------------------------------------
% This function computes a mixed misfit measure combining errors
% in  the  mean  and  the variability (coefficient of variation) 
% between model predictions and observed data:
% 
%      misfit = Weight * meanErr + (1 – Weight) * varErr
% 
% where
%
%   meanErr = ||uMean − dMean||^2 / ||dMean||^2
%   varErr  =  (covU − covData)^2 / covData^2
%
% and
%
%   uMean    = mean columns of model output U
%   dMean    = mean columns of data
%   covU     = sqrt(E[‖U‖^2] / ‖uMean‖^2 − 1)
%   covData  = sqrt(E[‖D‖^2] / ‖dMean‖^2 − 1)
%
%  Input:
%   (vector)          X      – model parameter vector (Nvars x 1)
%   (matrix)          Data   – observed data (nSamp x nReal)
%   (function_handle) fun    – handle to the predictive model
%   (scalar)          Weight – weight for mean error term
%  
%  Output:
%   (scalar)          misfit – combined error measure
% -----------------------------------------------------------------
function misfit = MisfitMeanVar(X,Data,fun,Weight)

    % check number of arguments
    if nargin < 3
        error('Too few inputs.');
    elseif nargin > 4
        error('Too many inputs.');
    elseif nargin == 3
        Weight = 0.5;
    end

    % check for consistency
    if ~isa(fun,'function_handle')
        error('fun must be a function handle.');
    end
    if ~isnumeric(X) || ~isvector(X)
        error('X must be a numeric vector.');
    end
    if ~isnumeric(Data) || ~ismatrix(Data)
        error('Data must be a numeric matrix.');
    end
    if ~isscalar(Weight) || Weight < 0 || Weight > 1
        error('Weight must be a scalar in [0,1].');
    end

    % stochastic model response
    U = fun(X);
    U = real(U);

    % central tendency error
    % --- means along realizations (columns) ---
    uMean     = mean(U,2);
    dMean     = mean(Data,2);
    normDMean = norm(dMean);
    if normDMean == 0
        error('Data mean norm is zero – cannot normalize.');
    end
    meanErr = (norm(uMean - dMean)/normDMean)^2;

    % variability error
    % --- second moments and coefficients of variation ---
    meanUNorm2 = mean(sum(U.^2,1));
    meanDNorm2 = mean(sum(Data.^2,1));
    covU       = sqrt(meanUNorm2 / norm(uMean)^2 - 1);
    covData    = sqrt(meanDNorm2 /   normDMean^2 - 1);
    if covData == 0
        error('Data coefficient of variation is zero – cannot normalize.');
    end
    varErr = ((covU - covData)/covData)^2;

    % combine errors in a scalar misfit measure
    misfit = Weight*meanErr + (1 - Weight)*varErr;
end
% -----------------------------------------------------------------