clc; clear; close all

% RGB intrinsic calibration parameters
% Freiburg 1
% % fx = 517.3;  % focal length x
% % fy = 516.5;  % focal length y
% % cx = 318.6;  % optical center x
% % cy = 255.3;  % optical center y
% 
% % Freiburg 2
% fx = 520.9;  % focal length x
% fy = 521.0;  % focal length y
% cx = 325.1;  % optical center x
% cy = 249.7;  % optical center y
% 
% % Freiburg 3
% % fx = 535.4;  % focal length x
% % fy = 539.2;  % focal length y
% % cx = 320.1;  % optical center x
% % cy = 247.6;  % optical center y
% 
% scaling_factor = 5000;  % depth scaling factor
% 
% % set this flag true if want edge extracted point clouds instead of full
% extract_edge = false;
% 
% % example folder
% exp_folder = 'examples';
% 
% % % Kinect intrinsic parameters
% % K = dlmread(fullfile(exp_folder, 'kinect_params.txt'));
% 
% % load (image, depth) pairs and ground truth relative pose
% % case_folder = 'case_1';
% case_folder = 'case_freibrug2';
% 
% 
% % load RGB image
% rgb1 = imread(fullfile(exp_folder, case_folder, 'img_prev.png'));
% rgb2 = imread(fullfile(exp_folder, case_folder, 'img_curr.png'));
% 
% % load Depth image
% depth1 = double(imread(fullfile(exp_folder, case_folder, 'dep_prev.png')));
% depth1(depth1 == 0) = nan;
% depth2 = double(imread(fullfile(exp_folder, case_folder, 'dep_curr.png')));
% depth2(depth2 == 0) = nan;
% 
% % compute points xyz
% points1 = double(rgb1);
% U1 = repmat(0:size(depth1,2)-1, size(depth1,1), 1);
% V1 = repmat([0:size(depth1,1)-1]', 1, size(depth1,2));
% points1(:,:,3) = depth1 / scaling_factor;
% points1(:,:,1) = (U1 - cx) .* points1(:,:,3) ./ fx;
% points1(:,:,2) = (V1 - cy) .* points1(:,:,3) ./ fy;
% point_cloud1 = pointCloud(points1, 'Color', rgb1);
% 
% points2 = double(rgb2);
% U2 = repmat(0:size(depth2,2)-1, size(depth2,1), 1);
% V2 = repmat([0:size(depth2,1)-1]', 1, size(depth2,2));
% points2(:,:,3) = depth2 / scaling_factor;
% points2(:,:,1) = (U2 - cx) .* points2(:,:,3) ./ fx;
% points2(:,:,2) = (V2 - cy) .* points2(:,:,3) ./ fy;
% point_cloud2 = pointCloud(points2, 'Color', rgb2);
% 
% 
% if extract_edge
%    point_cloud1 = ptcloud_edge_filter(point_cloud1);
%    point_cloud2 = ptcloud_edge_filter(point_cloud2);
% end
% 
% % ptCloudRef.Location = location_fixed;
% ptCloudRef = point_cloud1;
% 
% % ptCloudCurrent.Location = location_moving;
% ptCloudCurrent = point_cloud2;
% 
% % 
% % figure
% % subplot(1,2,1)
% % pcshow(ptCloudRef);
% % 
% % subplot(1,2,2)
% % pcshow(ptCloudCurrent);

%% load point cloud
freiburg2 = load('freiburg2.mat');
freiburg2 = freiburg2.freiburg2;
frame_idx = 1:3;

% 1-2, 2-3, 1-3
ptCloud1 = freiburg2{1};
ptCloud2 = freiburg2{2};
ptCloud3 = freiburg2{3};

%% downsample
dvo12 = rgbd_dvo1();
dvo23 = rgbd_dvo2();
dvo13 = rgbd_dvo3();
% downsample point clouds using grids
for percen = 0.08:0.02:0.12
    tic
    % moving - fixed : 1-2
    fixed1 = [];
    fixed1.ptcloud = removeInvalidPoints(pcdownsample(ptCloud2, 'random', percen));
    fixed1.image = rgb2gray(ptCloud2.Color);
    moving1 = removeInvalidPoints(pcdownsample(ptCloud1, 'random', percen));
    % make rkhs registration object
    dvo12.set_ptclouds(fixed1, moving1);
    dvo12.align();
    tform12 = dvo12.tform;
    disp('RGBD DVO Object Transformation Estimate:')
    disp(tform12.T')
    
    % moving - fixed : 2-3
    fixed2 = [];
    fixed2.ptcloud = removeInvalidPoints(pcdownsample(ptCloud3, 'random', percen));
    fixed2.image = rgb2gray(ptCloud3.Color);
    moving2 = removeInvalidPoints(pcdownsample(ptCloud2, 'random', percen));
    % make rkhs registration object
    dvo23.set_ptclouds(fixed2, moving2);
    dvo23.align();
    tform23 = dvo23.tform;
    disp('RGBD DVO Object Transformation Estimate:')
    disp(tform23.T')
    
    % moving - fixed : 1-3
    fixed3 = [];
    fixed3.ptcloud = removeInvalidPoints(pcdownsample(ptCloud3, 'random', percen));
    fixed3.image = rgb2gray(ptCloud3.Color);
    moving3 = removeInvalidPoints(pcdownsample(ptCloud1, 'random', percen));
    % make rkhs registration object
    dvo13.set_ptclouds(fixed3, moving3);
    dvo13.align();
    tform13 = dvo13.tform;
    disp('RGBD DVO Object Transformation Estimate:')
    disp(tform13.T')
    
    % joint optimization 
    Z_pre = cell(1,3);
    Z_pre{1} = tform12.T';
    Z_pre{2} = tform23.T';
    Z_pre{3} = tform13.T';
    Keys = cell(1,3);
    Keys{1} = [1,2];
    Keys{2} = [2,3];
    Keys{3} = [1,3];
    % pose is not the same as twist!
    % pose{1} = eye, pose{2} = tf(1->2), pos{3} = tf(1->3)
    jointPose = joint_optimization(Z_pre, Keys);
    pose2 = jointPose{2};
    pose3 = jointPose{3};
    
    % update transformation
    dvo12.tform.T = pose2';
    dvo23.tform.T = (pose2\pose3)';
    dvo13.tform.T = pose3';
    disp('Joint Optimization Transformation Estimate:')
    disp(dvo12.tform.T')
    disp(dvo23.tform.T')
    disp(dvo13.tform.T')
    
    toc
end

% transform 1 to 3
ptCloudtransformed1 = pctransform(ptCloud1,dvo13.tform);

mergeSize = 0.015;
ptCloudScene = pcmerge(ptCloud3, ptCloudtransformed1, mergeSize);

% Visualize the input images.
figure(2)
subplot(2,2,1)
imshow(ptCloud3.Color)
title('First input image')
drawnow

subplot(2,2,3)
imshow(ptCloud1.Color)
title('Second input image')
drawnow

% Visualize the world scene.
subplot(2,2,[2,4])
pcshow(ptCloudScene, 'VerticalAxis','Y', 'VerticalAxisDir', 'Down')
title('Initial world scene')
xlabel('X (m)')
ylabel('Y (m)')
zlabel('Z (m)')
drawnow

%% Stitch a Sequence of Point Clouds
% To compose a larger 3-D scene, repeat the same procedure as above to
% process a sequence of point clouds. Use the first point cloud to
% establish the reference coordinate system. Transform each point cloud to
% the reference coordinate system. This transformation is a multiplication
% of pairwise transformations.

% Store the transformation object that accumulates the transformation.
% accumTform = tform; 
% 
% figure
% hAxes = pcshow(ptCloudScene, 'VerticalAxis','Y', 'VerticalAxisDir', 'Down');
% title('Updated world scene')
% % Set the axes property for faster rendering
% hAxes.CameraViewAngleMode = 'auto';
% hScatter = hAxes.Children;
% 
% for i = 3:length(livingRoomData)
%     ptCloudCurrent = ptcloud_edge_filter(livingRoomData{i});
%        
%     % Use previous moving point cloud as reference.
%     fixed.ptcloud = moving;
%     % load RGB image
%     fixed.image = rgb2gray(livingRoomData{i}.Color);
%     moving = pcdownsample(ptCloudCurrent, 'gridAverage', gridSize);
%     
% %     tform = pc_gradient_descent(moving, fixed);
%     dvo.set_ptclouds(fixed, moving);
%     dvo.align();
%     tform = dvo.tform;
% 
%     % Transform the current point cloud to the reference coordinate system
%     % defined by the first point cloud.
%     accumTform = affine3d(tform.T * accumTform.T);
%     ptCloudAligned = pctransform(livingRoomData{i}, accumTform);
%     
%     % Update the world scene.
%     ptCloudScene = pcmerge(ptCloudScene, ptCloudAligned, mergeSize);
% 
%     % Visualize the world scene.
%     hScatter.XData = ptCloudScene.Location(:,1);
%     hScatter.YData = ptCloudScene.Location(:,2);
%     hScatter.ZData = ptCloudScene.Location(:,3);
%     hScatter.CData = ptCloudScene.Color;
%     drawnow('limitrate')
% end
% 
% % During the recording, the Kinect was pointing downward. To visualize the
% % result more easily, let's transform the data so that the ground plane is
% % parallel to the X-Z plane.
% angle = -pi/10;
% A = [1,0,0,0;...
%      0, cos(angle), sin(angle), 0; ...
%      0, -sin(angle), cos(angle), 0; ...
%      0 0 0 1];
% ptCloudScene = pctransform(ptCloudScene, affine3d(A));
% pcshow(ptCloudScene, 'VerticalAxis','Y', 'VerticalAxisDir', 'Down', ...
%         'Parent', hAxes)
% title('Updated world scene')
% xlabel('X (m)')
% ylabel('Y (m)')
% zlabel('Z (m)')
% toc;