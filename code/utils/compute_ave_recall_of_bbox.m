function [ ave_recall, recall,  thresholds] = compute_ave_recall_of_bbox( bbox_pred, bbox_gt, thresholds )

if ~exist('thresholds','var') || isempty(thresholds)
    thresholds = 0.5:0.05:0.95;
end

if iscell(bbox_pred)
    assert(iscell(bbox_gt));
    assert(length(bbox_pred) == length(bbox_gt));
    num_imgs = length(bbox_pred);
    overlap  = cell(num_imgs,1);
    for i = 1:num_imgs
        bbox_pred_this = bbox_pred{i};
        bbox_gt_this   = bbox_gt{i};
        num_bbox_gt    = size(bbox_gt_this,1);
        num_bbox_pred  = size(bbox_pred_this,1);
        overlap{i}      = zeros(num_bbox_gt,1,'single');
        
        
        if num_bbox_gt && num_bbox_pred
            [overlap{i}, ~] = closest_candidates(bbox_gt_this(:,1:4), bbox_pred_this(:,1:4));
            overlap{i} = single(overlap{i});
%             overlap{i} = max(boxoverlap(bbox_pred_this(:,1:4), bbox_gt_this(:,1:4)),[],1)';
        end
    end
    overlap = cell2mat(overlap);
else
    assert(size(bbox_pred,1) == size(bbox_gt,1));
    assert(size(bbox_pred,2) == size(bbox_gt,2));
    assert(size(bbox_pred,2) == 4);
    overlap = boxoverlap(bbox_pred, bbox_gt, true);
    assert(size(bbox_pred,1) == size(overlap,1));
    assert(size(overlap,2)==1);
end

[thresholds, recall, ave_recall] = compute_average_recall(overlap);

end

function [overlap, recall, AR] = compute_average_recall(unsorted_overlaps)
all_overlaps = sort(unsorted_overlaps(:)', 'ascend');
num_pos = numel(all_overlaps);
dx = 0.001;

overlap = 0:dx:1;
overlap(end) = 1;
recall = zeros(length(overlap), 1);
for i = 1:length(overlap)
recall(i) = sum(all_overlaps >= overlap(i)) / (num_pos+eps);
end

good_recall = recall(overlap >= 0.5);
AR = 2 * dx * trapz(good_recall);

if num_pos == 0
    AR = 0;
end
end

function [best_overlap,best_boxes] = closest_candidates(gt_boxes, candidates)
% do a matching between gt_boxes and candidates

  num_gt_boxes = size(gt_boxes, 1);
  num_candidates = size(candidates, 1);
  
%   iou_matrix = zeros(num_gt_boxes, num_candidates);
  iou_matrix = boxoverlap(candidates, gt_boxes)';
%   for i = 1:num_gt_boxes
%     iou = boxoverlap(gt_boxes(i,:), candidates);
%     iou_matrix(i,:) = iou';
%   end
  
  best_overlap = zeros(num_gt_boxes, 1);
  best_boxes = -ones(num_gt_boxes, 4);

  [best_overlap,best_boxes] = greedy_matching(iou_matrix, gt_boxes, candidates);
end

function [best_overlap,best_boxes] = greedy_matching(iou_matrix, gt_boxes, candidates)
  [n, m] = size(iou_matrix);
  assert(n == size(gt_boxes, 1));
  assert(m == size(candidates, 1));
  if n > m
    gt_matching = greedy_matching_rowwise(iou_matrix');
    candidate_matching = (1:m)';
  else
    gt_matching = (1:n)';
    candidate_matching = greedy_matching_rowwise(iou_matrix);
  end
  
  best_overlap = zeros(n, 1);
  best_boxes = zeros(n, 4);
  for pair_idx = 1:numel(gt_matching)
    gt_idx = gt_matching(pair_idx);
    candidate_idx = candidate_matching(pair_idx);
    
    best_overlap(gt_idx) = iou_matrix(gt_idx, candidate_idx);
    best_boxes(gt_idx,:) = candidates(candidate_idx, :);
  end
end

function [matching, objective] = greedy_matching_rowwise(iou_matrix)
  assert(size(iou_matrix, 1) <= size(iou_matrix, 2));
  n = size(iou_matrix, 1);
  matching = zeros(n, 1);
  objective = 0;
  for i = 1:n
    % find max element int matrix
    [max_per_row, max_col_per_row] = max(iou_matrix, [], 2);
    [max_iou,row] = max(max_per_row);
    if max_iou == -inf
      break
    end
    
    objective = objective + max_iou;
    col = max_col_per_row(row);
    matching(row) = col;
    iou_matrix(row,:) = -inf;
    iou_matrix(:,col) = -inf;
  end
end
