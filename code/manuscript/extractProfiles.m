function [inside_profile, outside_profile, handle_ip, handle_op, axis_output, labels, uncertain_profile] = extractProfiles(img, bMPC, bFlip, bAxis, bHandles, bFracture, cleaningIterations, bDebug)
%
%
%       [inside_profile, outside_profile, handle_ip, handle_op, axis_output, labels, uncertain_profile] =
%           extractProfiles(img, bMPC, bFlip, bAxis, bHandles, bFracture, cleaningIterations, bDebug)
%
%
% Digit
% An automatic MATLAB app for the digitalization of archaeological drawings. 
% http://vcg.isti.cnr.it
% 
% Copyright (C) 2016-17
% Visual Computing Laboratory - ISTI CNR
% http://vcg.isti.cnr.it
% Main author: Francesco Banterle
% 
% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this
% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%

if(~exist('bMPC', 'var'))
    bMPC = 0;
end

if(~exist('bFlip', 'var'))
    bFlip = 1;
end

if(~exist('bAxis', 'var'))
    bAxis = 0;
end

if(~exist('bHandles', 'var'))
    bHandles = 1;
end

if(~exist('bFracture', 'var'))
    bFracture = 0;
end

if(~exist('bDebug', 'var'))
    bDebug = 0;
end

outside_profile = [];
handle_ip = [];
handle_op = [];  
uncertain_profile = [];


[lines, axis_output , y_axis, labels] = imExtraction(img, cleaningIterations, bFlip, bAxis);

%
%
%compute inside profile
% 
%

[inside_profile, x_cut, y_cut] = extractInsideProfile(lines, y_axis, bHandles);

if(bDebug)
    figure(2);
    imshow(lines);
    hold on;    
    drawProfiles(inside_profile, [] );
end
    
%compute outside profile
[outside_profile, inside_profile, outside_profile_mouth, outside_profile_base, outside_profile_handle, bBrokenLoop] = extractOutsideProfile(lines, inside_profile, y_axis, x_cut, y_cut, bMPC, bHandles);

if(isempty(outside_profile))
    return
end

%clean unwanted thingies
y_max = max(outside_profile(:,2));
labels(y_max:end, :) = 0;

if(bHandles)
    bHandle = ~isempty(outside_profile_handle);
    
    if(bHandle)%process the handle 
        if(~bBrokenLoop)%compute handle profiles        
            [handle_op, handle_ip] = extractHandleProfile(lines, outside_profile, inside_profile,...
                                                          outside_profile_mouth, ...
                                                          outside_profile_handle, y_axis);
        else        
            lines2 = cleanLines(lines, outside_profile, 0);
            lines2 = cleanLines(lines2, inside_profile, 0);        

            [y, x] = find(lines2 > 0.5);

            p = outside_profile_base(1,:);
            d = (x - p(1)).^2 + (y - p(2)).^2;        
            [~, index] = min(d);

            if(bDebug)
                figure(43);
                imshow(lines2);
                hold on;
                plot(x(index), y(index), 'r+');
                hold off;
            end

            profile = lineCrawlerGen(lines2, x(index), y(index));

            if(~isempty(profile))
                [~, index2] = min(profile(:,2));
                handle_op = profile(1:index2, :);
                handle_op(:,1) = flipud(handle_op(:,1));
                handle_op(:,2) = flipud(handle_op(:,2));
                handle_ip_t = profile(index2:end, :);   
                handle_ip = fixInternalHandleProfile(handle_ip_t, outside_profile);

            end
        end

        %fix inside handle profile
        if(~isempty(handle_ip) & ~isempty(handle_op))

            mask = zeros(size(lines));
            mask = cleanLines(mask, addMissingSamples(outside_profile, 1), 1);

            %fix inside profile
            n = size(handle_ip, 1);
            start = round(n / 3);
            last_white = -1;
            for i=1:start
                x = handle_ip(i, 1);
                y = handle_ip(i, 2);

                if(mask(y, x) == 1)
                    last_white = i;
                end
            end

            if(last_white > 0)
                handle_ip(1:last_white, :) = [];
            end

            %fix outside profile
            n = size(handle_op, 1);
            start = round(n / 3);
            last_white = -1;
            for i=1:start
                x = handle_op(i, 1);
                y = handle_op(i, 2);

                if(mask(y, x) == 1)
                    last_white = i;
                end
            end

            if(last_white > 0)
        %         tmp = handle_op(1:last_white, :);

        %         [~, index] = findClosestPointInProfile(outside_profile, tmp(:,1));
        %         
        %         op_1 = outside_profile(1:index,:);
        %         op_2 = outside_profile((index + 1):end,:);
        %         
        %         outside_profile = [op_1; tmp; op_2];        

                handle_op(1:last_white, :) = [];
            end    
            %mask = imdilate(mask, ones(5));

            if(bDebug)
                figure(10);
                imshow(mask);
                hold on;
            end
        end

        if(bBrokenLoop)
            %attach the ip and op profiles of the handle to the outisde profile    
            handle_ip = attachInternalProfileToOP(handle_ip, outside_profile);
            handle_op = attachOutsideProfileToOP(handle_op, outside_profile, 0);
        end
    else %are we sure there is no handle? sanity check
        %get the handle
        lst = unique(labels(labels > 0));
        n = length(lst);

        y_axis = round((axis_output(1,1) + axis_output(2,1)) / 2);
        x_axis = round((axis_output(1,2) + axis_output(2,2)) / 2);

        l_size_max = 1e20;
        lst_index_max = -1;
        for i=1:n
            mt = zeros(size(img));
            mt(labels == lst(i)) = 1;
            [yr,xc] = find(mt > 0.5);

            dist = ((yr - x_axis).^2 + (xc - y_axis).^2);
            distindex = find(yr <= y_axis);

            if(~isempty(distindex))        
                v = sqrt(min(dist(distindex)));

                if(v < l_size_max)
                    l_size_max = v;
                    lst_index_max = i;
                end
            end        
        end

        if(lst_index_max > 0)

            handle_mask = zeros(size(img));
            handle_mask(labels == lst(lst_index_max)) = 1;

            labels(labels == lst(lst_index_max)) = 0;

            handle_lines = bwmorph(handle_mask, 'remove');
            handle_lines = bwmorph(handle_lines, 'thin');

            [y, x] = find(handle_lines > 0.5);

            [~, indx] = findClosestPointInProfile([x,y], outside_profile(1,:));

            [y_max, ~] = max(y);

            handle_profile = lineCrawlerGen(handle_lines, x(indx), y(indx), y_max + 1);

            if(~isempty(handle_profile))
                orientation = getPolylineOrientation(handle_profile, 5);

                if(~orientation)
                    handle_profile = flipud(handle_profile);
                end

                [~, index_min] = max(handle_profile(:,2));

                handle_op = handle_profile(1:index_min,:);

                handle_ip_t = handle_profile((index_min + 1):(end - 1),:);
                handle_ip_t = flipud(handle_ip_t);

                handle_ip = fixInternalHandleProfile(handle_ip_t, outside_profile);

                %attach the ip and op profiles of the handle to the outisde profile
                handle_ip = attachInternalProfileToOP(handle_ip, outside_profile);
                handle_op = attachOutsideProfileToOP(handle_op, outside_profile, 1);
            end
        end
    end
end

if(bDebug)
    drawProfiles(handle_ip, handle_op);
end

%add missing samples
outside_profile = addMissingSamples(outside_profile, 0);
        
if(isempty(handle_ip))%base point
    [~, index_closest_to_axis] = min(abs(inside_profile(:,1) - y_axis));

    profile_to_be_added = inside_profile((index_closest_to_axis + 1):end, :);

    if(~isempty(profile_to_be_added))
        inside_profile((index_closest_to_axis + 1):end, :) = [];

        outside_profile = [outside_profile; flipud(profile_to_be_added)];
    end
end

%case lid
% [~,index] = max(abs(outside_profile(:,2)));
% tmp = outside_profile((index+1):end,:);
% outside_profile((index+1):end,:) = [];
% inside_profile = [inside_profile; flipud(tmp)];

%remove axis from profile
inside_profile = removePointsCloseToAxis(inside_profile, y_axis, 16);
outside_profile = removePointsCloseToAxis(outside_profile, y_axis, 16);

%remove
uncertain_profile = [];

if(bFracture)
    hf = figure(1);
    imshow(1 - lines);
    hold on;
    
    p1 = round(ginput(1));
    plot(p1(1), p1(2), 'r+');

    p2 = round(ginput(1));
    plot(p2(1), p2(2), 'r+');
    
    nIP = size(inside_profile, 1);
    nOP = size(outside_profile, 1);
    
    [v1, indx1] = findClosestPointInProfile(inside_profile, p1);
    [v2, indx2] = findClosestPointInProfile(inside_profile, p2);
    
    if(v1 < v2)
        vCut = indx1;
    else
        vCut = indx2;
    end
    
    uncertain_profile = inside_profile((vCut + 1):end, :);    
    inside_profile = inside_profile(1:vCut, :);
    

    [v1, indx1] = findClosestPointInProfile(outside_profile, p1);
    [v2, indx2] = findClosestPointInProfile(outside_profile, p2);

    if(v1 < v2)
        vCut = indx1;
    else
        vCut = indx2;
    end

    uncertain_profile = [uncertain_profile; flipud(outside_profile((vCut + 1):end, :))];    
    outside_profile = outside_profile(1:vCut, :);
    
    close(hf);
end

end

%
%
%
function handle_ip = fixInternalHandleProfile(handle_ip_t, outside_profile)

    dist = [];
    handle_ip = [];
    
    for i=1:size(handle_ip_t, 1)
       p = handle_ip_t(i,:);
       [d, ~] = findClosestPointInProfile(outside_profile, p);
       dist = [dist, d];
    end

    if(~isempty(dist))
        dist = sqrt(dist);
        
        thr = mean(dist) - 0.5 * std(dist);
        
        x_t = handle_ip_t(:, 1);
        y_t = handle_ip_t(:, 2);
        
        index_tmp = find(dist > thr);
        
        if(~isempty(index_tmp))
            handle_ip(:,1) = x_t(index_tmp);
            handle_ip(:,2) = y_t(index_tmp);
        end
    end
end

%
%
%
function handle_ip_out = attachInternalProfileToOP(handle_ip, outside_profile)

    if(size(handle_ip,1) > 2)    
        p_t = handle_ip(1,:) - handle_ip(2,:);
        p_t = p_t / norm(p_t);            
        [~, index] = findClosestPointInProfile(outside_profile, handle_ip(1,:), p_t);            
        handle_ip = [outside_profile(index,:) ; handle_ip];

        p_t = handle_ip(end,:) - handle_ip(end-1,:);
        p_t = p_t / norm(p_t);            
        [~, index] = findClosestPointInProfile(outside_profile, handle_ip(end,:), p_t);            
        handle_ip_out = [handle_ip; outside_profile(index,:)];
    else
        handle_ip_out = handle_ip;
    end
end

%
%
%
function handle_op_out = attachOutsideProfileToOP(handle_op, outside_profile, full)
    if(size(handle_op,1) > 2)

        p_t = handle_op(1,:) - handle_op(2,:);
        p_t = p_t / norm(p_t);       
        [~, index] = findClosestPointInProfile(outside_profile, handle_op(1,:), p_t);    

        handle_op_out = [outside_profile(index,:) ; handle_op];

        if(full)
            p_t = handle_op(end,:) - handle_op(end-1,:);
            p_t = p_t / norm(p_t);            
            [~, index] = findClosestPointInProfile(outside_profile, handle_op(end,:), p_t);            
            handle_op_out = [handle_op_out; outside_profile(index,:)];
        end
    else
        handle_op_out = handle_op;
    end
end