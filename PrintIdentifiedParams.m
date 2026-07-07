% -----------------------------------------------------------------
% PrintIdentifiedParams.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 22, 2025
%            Last update in: Jul 22, 2025
% -----------------------------------------------------------------
% This function prints a formatted list of identified parameter
% names and their values to the command window, matching the style:
%
%   ........................
%    Identified Parameters
%   ........................
%     name1 = value1
%     name2 = value2
%     ...
%   ........................
%
% Input:
%   names  ? cell array of strings, parameter names (1 x N or N x 1)
%   values ? numeric vector of length N, parameter values
%
% Output:
%   (none) ? prints to screen
% -----------------------------------------------------------------
function PrintIdentifiedParams(names, values)

    % argument checks
    if nargin<2
        error('Too few inputs.');
    elseif nargin>2
        error('Too many inputs.');
    end
    if ~iscellstr(names) || ~isvector(names)
        error('names must be a cell array of strings.');
    end
    if ~isnumeric(values) || ~isvector(values)
        error('values must be a numeric vector.');
    end
    N = numel(names);
    if numel(values)~=N
        error('names and values must have the same length.');
    end

    % Determine padding for alignment
    nameLengths = cellfun(@length, names);
    maxLen = max(nameLengths);

    % Print header
    disp(' ');
    disp(' ........................');
    disp('  Identified Parameters  ');
    disp(' ........................');

    % Print each name = value line
    for k = 1:N
        name = names{k};
        padding = repmat(' ', 1, maxLen - length(name));
        disp(['  ' name padding ' = ' num2str(values(k))]);
    end

    % Print footer
    disp(' ........................');
    disp(' ');
end
% -----------------------------------------------------------------
