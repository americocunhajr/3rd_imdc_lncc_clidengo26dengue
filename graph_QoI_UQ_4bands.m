% -----------------------------------------------------------------
% graph_QoI_UQ_4bands.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%
%  Originally programmed in: Jul 30, 2025
%            Last update in: Jul 30, 2025
% -----------------------------------------------------------------
% This function plots:
%   * observed data (yData)
%   * Monte‐Carlo samples (MCsamples)
%   * median trajectory (yMedian)
%   * four confidence bands (yLow(:,k), yHigh(:,k), k=1:4)
% Confidence bands are shaded in progressively darker gray.
%
% Input:
%   time         – (1 x N or N x 1) time vector
%   yData        – (nSamp x nReal) observed data
%   yMean        – (1 x N or N x 1) mean trajectory
%   yMedian      – (1 x N or N x 1) median trajectory
%   yLow         – (nBands x N) lower bounds of bands
%   yHigh        – (nBands x N) upper bounds of bands
%   graphObj     – struct with fields:
%       * gname    – figure name/title
%       * colorMed   – color for median line
%       * legData    – legend entry for raw data
%       * legMed     – legend entry for median
%       * legBand    – 1 x nBands cell array of legend entries for each band
%       * xmin,xmax  – x‐limits or 'auto'
%       * ymin,ymax  – y‐limits or 'auto'
%       * xlab,ylab  – axis labels
%       * title      – plot title
%
% Output:
%   fig – handle to the created figure
% -----------------------------------------------------------------
function fig = graph_QoI_UQ_4bands(time,yData,yMean,yMedian,yLow,yHigh,graphObj)

    % argument checks
    if nargin < 7
        error('Too few inputs.');
    elseif nargin > 7
        error('Too many inputs.');
    end

    % vectors
    if ~isvector(time) || ~isvector(yMedian) || ~isvector(yMean)
        error('time, and yMean, yMedian must be vectors.');
    end
    N = numel(time);
    if numel(yMedian)~=N
        error('time, and yMedian must be same length.');
    end
    if numel(yMean)~=N
        error('time, and yMean must be same length.');
    end

    % bands
    [nBands, NB] = size(yLow);
    if nBands ~= 4 || any(size(yHigh) ~= [4 NB]) || NB ~= N
        error('yLow and yHigh must be 4 x N matrices.');
    end

    % ensure row orientation for plotting
    time    = time(:)';
    yMean   = yMean(:)';
    yMedian = yMedian(:)';
    for k=1:4
        yLow(k,:)  = yLow(k,:)';
        yHigh(k,:) = yHigh(k,:)';
    end

    % define gray levels for bands (light -> dark)
    % 95%, 90%, 80%, 50%
    grayLevels = [0.9, 0.75, 0.50, 0.25];  
    
    % create figure and hold
    fig = figure('Name', graphObj.gname, 'NumberTitle','off');
    hold on

    % plot MC samples, median, confidence bands and raw data
    hBands = gobjects(nBands,1);
    for k=1:nBands
        xPatch = [time, fliplr(time)];
        yPatch = [yHigh(k,:), fliplr(yLow(k,:))];
        hBands(k) = fill(xPatch, yPatch, grayLevels(k)*[1 1 1], ...
                         'EdgeColor','none', 'FaceAlpha', 1);
    end

    hMed = plot(time,yMedian,'-' ,'Color',graphObj.colorMed, ...
                                       'LineWidth',3, ...
                                       'DisplayName',graphObj.legMed);

    hMean = plot(time,yMean,'--' ,'Color',graphObj.colorMean, ...
                                       'LineWidth',3, ...
                                       'DisplayName',graphObj.legMed);

    hRaw = plot(time,yData     ,'o--','Color','g', ...
                                       'MarkerSize',6,...
                                       'LineWidth',1.5, ...
                                       'DisplayName', graphObj.legData);


    % axes formatting
    set(gcf, 'Color','none');
    ax = gca;
    set(ax, 'Box','on', 'TickDir','out', 'FontName','Helvetica', 'FontSize',14);

    % x-limits (handle datetime or numeric)
    if isfield(graphObj,'xmin') && isfield(graphObj,'xmax') && ...
       ~(isequal(graphObj.xmin,'auto') || isequal(graphObj.xmax,'auto'))
        xmin = graphObj.xmin;
        xmax = graphObj.xmax;
        if isdatetime(time)
            if ~isdatetime(xmin); error('xmin must be datetime when time is datetime.'); end
            if ~isdatetime(xmax); error('xmax must be datetime when time is datetime.'); end
            xlim([xmin, xmax]);
        else
            if isdatetime(xmin); xmin = datenum(xmin); end
            if isdatetime(xmax); xmax = datenum(xmax); end
            xlim([xmin, xmax]);
        end
    end

    % y-limits
    if isfield(graphObj,'ymin') && isfield(graphObj,'ymax') && ...
       ~(isequal(graphObj.ymin,'auto') || isequal(graphObj.ymax,'auto'))
        ylim([graphObj.ymin, graphObj.ymax]);
    end

    % x-axis tick formatting
    if isdatetime(time)
        ax.XAxis.TickLabelFormat = 'yyyy-MM';
        xtickangle(30);
    else
        datetick(ax, 'x', 'keeplimits', 'keepticks');
        xtickangle(30);
    end

    xlabel(graphObj.xlab, 'FontSize',16);
    ylabel(graphObj.ylab, 'FontSize',16);
    title(graphObj.title, 'FontSize',18);


    % Add logo image to the northwest part of the plot
    axes('Position',[0.93 0.9 0.05 0.05]);
    imshow('logo/D-FENSE.png');
    axis off;

    % legend
    hLeg = legend([hBands; hMed; hMean; hRaw], ... 
                  [graphObj.legBand(:); ...
                   graphObj.legMed; ...
                   graphObj.legMean; ...
                   graphObj.legData;...
                   ], ...
                  'Location','NorthWest');
    set(hLeg, 'FontSize',12);

    hold off

    % Add author name outside the plot area, parallel to y-label
    if isfield(graphObj, 'signature') && ~isempty(graphObj.signature)
        annotation('textbox', [0.98, 0.2, 0.5, 0.5], 'String', ...
            graphObj.signature, 'FontSize', 12, ...
            'FontName', 'Helvetica', 'Color', [0.5 0.5 0.5], ...
            'Rotation', 90, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'EdgeColor', 'none');
    end

    % Save the plot as an EPS file if required
    if strcmp(graphObj.print, 'yes')
        print('-depsc2', [graphObj.gname, '.eps']);
        print('-dpng'  , [graphObj.gname, '.png']);
    end

    % Close the figure if requested
    if strcmp(graphObj.close, 'yes')
        close(fig);
    end
end
% -----------------------------------------------------------------
