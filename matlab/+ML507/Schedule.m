classdef Schedule < handle
    properties (Access = protected, Hidden = true)
        ml;
        type;
    end
    
    methods
        function obj = Schedule(ml, type)
            obj.ml = ml;
            obj.type = type;
        end
        
        function n = numel(obj, varargin)
            n = 6;
        end
        
        function [varargout] = subsref(obj, S)
            if length(S.subs) ~= 1 || strcmp(S.type, '()') == 0
                error('invalid syntax')
            end
            index = cell2mat(S.subs);
            varargout = mat2cell(arrayfun(@(x) obj.ml.query(sprintf('%s%d', obj.type, x-1)), index, 'UniformOutput', false),1);
        end
        
        function obj = subsasgn(obj, S, b)
            if length(S.subs) ~= 1 || strcmp(S.type, '()') == 0
                error('invalid syntax')
            end
            index = cell2mat(S.subs);
            if size(index) ~= size(b)
                error('invalid syntax')
            end
            arrayfun(@(which, val) obj.ml.setValue(sprintf('%s%d', obj.type, which-1), val), index, b, 'UniformOutput', false);
        end
    end
end