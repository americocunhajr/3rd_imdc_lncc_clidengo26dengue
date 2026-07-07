% -----------------------------------------------------------------
% ApplyFilter.m
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr
%               americo.cunhajr@gmail.com
%               
%               Christian Soize
%               christian.soize@univ-eiffel.fr
%
%  Originally programmed in: Feb 14, 2025
%            Last update in: Jul 10, 2025
% -----------------------------------------------------------------
% This function applies a convolution-based filter to a numeric
% vector, managing edge effects by replicating boundary values.
% The  filter  coefficients  are  stored in the vector a, which
% should  sum  to  1  and  its  length  must  be  odd,  i.e., 
% length(a) = 2*m+1.
%
% Input:
%   data         - numeric vector (row or column)
%   FilterCoeffs - numeric vector of filter coefficients (odd length)
%
% Output:
%   data_hat      - filtered numeric vector of the same orientation
%                   and length as data
% -----------------------------------------------------------------
function data_hat = ApplyFilter(data,FilterCoeffs)

    % check number of arguments
    if nargin < 2
        error('Too few inputs.');
    elseif nargin > 2
        error('Too many inputs.');
    end

    % input must be numeric vectors
    if ~isnumeric(data) || ~isvector(data)
        error('data must be a numeric vector.');
    end
    if ~isnumeric(FilterCoeffs) || ~isvector(FilterCoeffs)
        error('FilterCoeffs must be a numeric vector.');
    end

    % ensure filter length is odd
    if mod(length(FilterCoeffs),2) ~= 1
        error('Length of FilterCoeffs must be odd (2*m+1).');
    end

    % normalize filter coefficients
    FilterCoeffs = FilterCoeffs(:);
    FilterCoeffs = FilterCoeffs / sum(FilterCoeffs);

    % determine half-window size
    m = floor(length(FilterCoeffs)/2);

    % manage edge effects by padding data with its boundary values
    if isrow(data)
        data_pad = [repmat(data(1), 1, m), data, repmat(data(end), 1, m)];
    else
        data_pad = [repmat(data(1), m, 1); data; repmat(data(end), m, 1)];
    end

    % apply convolution and extract valid part
    data_hat = conv(data_pad, FilterCoeffs, 'valid');
end
% -----------------------------------------------------------------