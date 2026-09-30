classdef Dimension
% DIMENSION One dimension token in a property shape.
%
% A Dimension object represents either:
%
% - a fixed integer dimension
% - a symbolic named dimension
%
% Parameters
% ----------
% kind : char
%     Dimension kind. Must be 'fixed' or 'symbolic'.
% value : numeric or char
%     Dimension value.
%
% Notes
% -----
% Shapes are represented as ordered arrays of Dimension objects. Scalar
% properties are represented by an empty Dimension array.
%
% See Also
% --------
% PropertyDefinition

    properties (SetAccess=private)
        kind
        value
    end

    methods
        function obj = Dimension(kind, value)
        % Create a dimension token.
        %
        % Parameters
        % ----------
        % kind : char
        %     Dimension kind. Must be 'fixed' or 'symbolic'.
        % value : numeric or char
        %     Dimension value.
        %
        % Raises
        % ------
        % error
        %     Raised if the dimension kind or value is invalid.
            if ~(ischar(kind) || isstring(kind))
                error('Dimension kind must be a string.');
            end
            kind = char(string(kind));

            if ~ismember(kind, {'fixed','symbolic'})
                error('Dimension kind must be either "fixed" or "symbolic".');
            end

            switch kind
                case 'fixed'
                    if ~(isnumeric(value) && isscalar(value) && value > 0 && mod(value,1)==0)
                        error('Fixed dimension value must be a positive integer.');
                    end
                case 'symbolic'
                    if ~(ischar(value) || isstring(value))
                        error('Symbolic dimension value must be a string.');
                    end
                    value = char(string(value));
                    if isempty(strtrim(value))
                        error('Symbolic dimension value must be nonempty.');
                    end
            end

            obj.kind = kind;
            obj.value = value;
        end

        function out = is_fixed(obj)
        % Return whether this dimension is fixed-size.
        %
        % Returns
        % -------
        % out : logical
        %     True if the dimension is fixed-size.
            out = strcmp(obj.kind, 'fixed');
        end

        function out = is_symbolic(obj)
        % Return whether this dimension is symbolic.
        %
        % Returns
        % -------
        % out : logical
        %     True if the dimension is symbolic.
            out = strcmp(obj.kind, 'symbolic');
        end

        function out = char(obj)
        % Return a character representation of the dimension.
        %
        % Returns
        % -------
        % out : char
        %     Character representation of the dimension token.
            if isnumeric(obj.value)
                out = num2str(obj.value);
            else
                out = obj.value;
            end
        end
    end

    methods (Static)
        function obj = fixed(value)
        % Construct a fixed dimension.
        %
        % Parameters
        % ----------
        % value : numeric
        %     Positive integer dimension size.
        %
        % Returns
        % -------
        % obj : Dimension
        %     Fixed dimension object.
            obj = Dimension('fixed', value);
        end

        function obj = symbolic(value)
        % Construct a symbolic dimension.
        %
        % Parameters
        % ----------
        % value : char
        %     Symbolic dimension name.
        %
        % Returns
        % -------
        % obj : Dimension
        %     Symbolic dimension object.
            obj = Dimension('symbolic', value);
        end
    end
end