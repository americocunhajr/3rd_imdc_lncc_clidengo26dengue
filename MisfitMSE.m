% -----------------------------------------------------------------
%  MisfitMSE.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%               
%  Initially Programmed: Jul 11, 2025
%           Last Update: Jul 17, 2025
% -----------------------------------------------------------------
% This function computes a model-data misfit by decomposing the
% mean-square error (MSE) into:
%   - squared bias of the column-means
%   - variance of the model predictions
%
%   misfit = ||meanPred - meanData||^2 + E[||U - meanPred||^2]
%
% where
%  
%   meanPred = mean columns of U
%   meanData = mean columns of Data
%
%  Input:
%   (vector)          X      - model parameter vector (Nvars x 1)
%   (matrix)          Data   - observed data (nSamp x nReal)
%   (function_handle) fun    - handle to the predictive model
%  
%  Output:
%   (scalar)          misfit - relative MSE
% -----------------------------------------------------------------
function misfit = MisfitMSE(X,Data,fun)

    % check number of arguments
    if nargin < 3
        error('Too few inputs.');
    elseif nargin > 3
        error('Too many inputs.');
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

    % stochastic model prediction
    U = fun(X);

    % compute column-means of predictions and data
    meanPred = mean(U,2);
    meanData = mean(Data,2);

    % squared bias term
    bias2 = norm(meanPred-meanData)^2;

    % prediction variance term
    varPred  = mean(sum((U-meanPred).^2,1));

    % compute the MSE misfit
    misfit = bias2 + varPred;
end
% -----------------------------------------------------------------