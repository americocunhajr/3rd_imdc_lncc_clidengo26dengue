% -----------------------------------------------------------------
% RemoveNonNegativeValues.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 09, 2025
%            Last update in: Jul 10, 2025
% -----------------------------------------------------------------
% This  function  removes  potentially  non-negative  finite values
% from a given numeric array, replacing them with half the smallest
% positive finite value present.
% 
% Input:
%   data  - numeric array (scalar, vector, or matrix)
%
% Output:
%   data  - numeric array of  the same size as input,  where all
%           non-positive   finite  entries  have  been  replaced
%           with half the minimum positive finite value from the
%           original data.
% -----------------------------------------------------------------
function data = RemoveNonNegativeValues(data)

    % check number of arguments
    if nargin < 1
        error('Too few inputs.');
    elseif nargin > 1
        error('Too many inputs.');
    end

    % input must be numeric
    if ~isnumeric(data)
        error('data must be numeric.');
    end

    % find strictly positive finite entries
    pos = data > 0 & isfinite(data);

    % require at least one positive finite value
    if ~any(pos(:))
        error('data must contain at least one positive finite value.');
    end

    % compute replacement value from positives only
    halfMin = min(data(pos))/2;
    
    % replace non-positive or non-finite entries
    data(~pos) = halfMin;
end
% -----------------------------------------------------------------