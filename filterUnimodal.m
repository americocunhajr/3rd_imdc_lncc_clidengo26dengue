function [isUnimodal, X_keep] = filterUnimodal(X, varargin)
% X: nT x nSeries (time along rows)
% Name-Value: 'SmoothWindow' (odd integer, default 5), 
%             'MinProminence' (default 0.1*range), 
%             'MinPeakHeight' (default -inf)
p = inputParser;
addParameter(p,'SmoothWindow',5,@(v)isnumeric(v)&&(mod(v,2)==1));
addParameter(p,'MinProminence',[],@isnumeric);
addParameter(p,'MinPeakHeight',-inf,@isnumeric);
parse(p,varargin{:});
w = p.Results.SmoothWindow;
mprom = p.Results.MinProminence;
mh = p.Results.MinPeakHeight;

[nT,nS] = size(X);
isUnimodal = false(1,nS);

for i = 1:nS
    ts = X(:,i);
    % basic preprocessing: remove NaNs and center/scale optional
    if all(isnan(ts)) || all(ts==0)
        isUnimodal(i) = false;
        continue
    end
    % smooth to reduce spurious peaks
    ts_s = movmedian(ts, w, 'omitnan');
    % set default prominence if empty (relative to series range)
    if isempty(mprom)
        mprom = 0.1 * (max(ts_s) - min(ts_s));
    end
    % find peaks
    [pks, locs, ~, proms] = findpeaks(ts_s, 'MinPeakProminence', mprom, 'MinPeakHeight', mh);
    % unimodal if exactly one prominent peak
    isUnimodal(i) = (numel(pks) == 1);
end

% return filtered data (keep columns that are unimodal)
X_keep = X(:, isUnimodal);
end
