classdef Schedule < handle
    properties (Access = protected, Hidden = true)
        ml;
    end
    
    methods
        function obj = Schedule(ml)
            obj.ml = ml;
        end
        
        function n = numel(obj, varargin)
            n = 6;
        end
        
        function [varargout] = subsref(obj, S)
            if length(S.subs) ~= 1 || strcmp(S.type, '()') == 0
                error('invalid syntax')
            end
            x = cell2mat(S.subs);
            x
        end
        
        function [varargout] = subsasgn(obj, S, b)
            %    type: '()'
            %    subs: {[2]}
            S
%            if length(S.subs) ~= 1
%                error('invalid syntax')
%            end
            S.subs(1)
            b
        end
    end
end

