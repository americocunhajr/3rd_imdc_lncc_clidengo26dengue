% -----------------------------------------------------------------
% NormalizeData.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 14, 2025
%            Last update in: Jul 14, 2025
% -----------------------------------------------------------------
% This function performs min–max normalization of a dataset:
%   Xnorm = (Xmed − Xmin) ./ (Xmax − Xmin)
% It supports scalar or vector Xmin and Xmax (broadcast to match Xmed).
%  
% Input:
%   (numeric vector          ) Xmed  – data to normalize
%   (numeric scalar or vector) Xmin – minimum value(s)
%   (numeric scalar or vector) Xmax – maximum value(s)
%
% Output:
%   (numeric vector) Xnorm – normalized data (same size as Xmed)
% -----------------------------------------------------------------
function Xnorm = NormalizeData(Xmed,Xmin,Xmax)

    % check number of arguments
    if nargin < 3
        error('Too few inputs.');
    elseif nargin > 3
        error('Too many inputs.');
    end

    % input must be numeric vectors
    if ~isnumeric(Xmed) || ~isvector(Xmed)
        error('Xmed must be a numeric vector.');
    end
    if ~isnumeric(Xmin) || ~isvector(Xmin)
        error('Xmin must be a numeric scalar or vector.');
    end
    if ~isnumeric(Xmax) || ~isvector(Xmax)
        error('Xmax must be a numeric scalar or vector.');
    end

    % broadcast scalars to match Xmed
    sz = size(Xmed);
    if isscalar(Xmin)
        Xmin = repmat(Xmin, sz);
    elseif ~isequal(size(Xmin), sz)
        error('Xmin must be scalar or the same size as Xmed.');
    end
    if isscalar(Xmax)
        Xmax = repmat(Xmax, sz);
    elseif ~isequal(size(Xmax), sz)
        error('Xmax must be scalar or the same size as Xmed.');
    end

    % check that max exceeds min
    D = Xmax - Xmin;
    if any(D <= 0)
        error('Each element of Xmax must exceed Xmin.');
    end

    % perform normalization
    Xnorm = (Xmed-Xmin)./D;
end
% -----------------------------------------------------------------