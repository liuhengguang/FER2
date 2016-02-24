function varargout = conv_layer(X, layer, varargin)
%CONV_LAYER convolution layer
%
% It performs:
%   Forward pass: [y, layer] = conv_layer(X, layer)
%   Backward pass: [dX, dW] = conv_layer(X, layer, dy)
%
% Inputs:
%   - X: inputs sized [H,W,C,N]
%   - layer: convolution layer, with
%       - W: conv weights sized [kH,kW,C,kN] (kN filters, each sized [kH,kW,C])
%       - pad: 0 padding
%       - stride
%       - M: im2col results sized [kH*kW*C, oH*oW, N]
%
% Outputs:
%   - y: activations sized [oH,oW,kN,N]
%   - dX: input gradients sized [H,W,C,N]
%   - dW: weight gradients sized [kH,kW,C,kN]
%

% use global variables for passing params easily
global H W C N kH kW kN oH oW S P

if ~isfield(layer, 'stride')
    layer.stride = 1;
end

if ~isfield(layer, 'pad')
    layer.pad = 0; % if H=W, set pad to (kH-1)/2 to keep the input size,
end

% Input size
[H,W,C,N] = size(X);
[kH,kW,~,kN] = size(layer.W);

S = layer.stride;
P = layer.pad;

% Output size
oH = floor((H+2*P-kH)/S+1);
oW = floor((W+2*P-kW)/S+1);

if ~isfield(layer, 'input_size')
    layer.input_size = [H,W,C,N];
    layer.output_size = [oH,oW,kN,N];
end

if nargin == 2 || isempty(varargin)
    % forward pass
    % Padding
    X = padarray(X, [P,P]); % [H+2P,W+2P,C]
    
    weights = reshape(layer.W, [], kN);  % [kH*kW*C, kN]
    layer.M = zeros(kH*kW*C, oH*oW, N);  % cache im2col results of each image
    
    y = zeros(oH,oW,kN,N);
    for i = 1:N
        im = X(:,:,:,i);
        % im2col
        M = im2col(im);  % [kH*kW*C, oH*oW]
        layer.M(:,:,i) = M;                 % cache for BP use
        % convolution as matrix production
        a = M'*weights;                     % [oH*oW, kN]
        % reshape to output tensor
        y(:,:,:,i) = reshape(a, oH, oW, kN);
    end
    
    % output
    varargout{1} = y;
    varargout{2} = layer;
else
    % backward pass
    dy = varargin{1};
    weights = reshape(layer.W, [], kN);
    
    dy = reshape(dy, oH*oW, kN, N);
    dX = zeros(size(X));            % [H,W,C,N]
    dW = zeros(kH*kW*C, kN);        % [kH*kW*C, kN]
    for i = 1:N
        dyi = dy(:,:,i);            % [oH*oW, kN]
        M = layer.M(:,:,i);         % [kH*kW*C, oH*oW]
        dW = dW + M * dyi;          % [kH*kW*C, kN]
        
        dM = weights * dyi';        % [kH*kW*C, oH*oW]
        dX(:,:,:,i) = col2im(dM);   % [H,W,C]
    end
    
    % output
    varargout{1} = dX; 
    varargout{2} = dW; 
end


function M = im2col(im)
% IM2COL convert a image to cols for convolution
%
% Inputs:
%   - im: one image sized [H,W,C]
%   - kH, kW: kernel size
%   - oH, oW: output size
%   - S: stride
%
% Output:
%   - M: a matrix sized [kH*kW*C, N], N is the # of activation fields
%

global kH kW oH oW C S

M = zeros(kH*kW*C, oH*oW);
i = 1;
for w = 1:oW
    x = 1+(w-1)*S;
    for h = 1:oH
        y = 1+(h-1)*S;
        cube = im(y:y+kH-1, x:x+kW-1, :);
        
        M(:,i) = cube(:); % reshape to 1 column
        i = i+1;
    end
end


function im = col2im(M)
% COL2IM: convert column gradients back to original image gradients
%
% Inputs:
%   - M: sized [kH*kW*C, oH*oW]
%   - H,W,C: im size
%   - kH,kW: kernel size
%   - S: stride
%
% Outputs:
%   - im: the orignal image gradients, sized [H,W,C]
%

global H W C kH kW oH oW S

im = zeros(H,W,C);
i = 1;
for w = 1:oW
    x = 1+(w-1)*S;
    for h = 1:oH
        y = 1+(h-1)*S;
        
        col = M(:,i);                   % [kH*kW*C, 1]
        col = reshape(col, kH, kW, C);  % [kH,kW,C]
        
        % collect the gradients
        im(y:y+kH-1, x:x+kW-1, :) = im(y:y+kH-1, x:x+kW-1, :) + col;
        i = i+1;
    end
end








