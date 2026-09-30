classdef ConstraintRule
% CONSTRAINTRULE Canonical specification-level cross-property constraint.
%
% A ConstraintRule represents a relational rule between properties at the
% specification level.
%
% Parameters
% ----------
% kind : char
%     Constraint kind, such as requires, paired, all_or_none, or
%     exactly_one_of.
% subject_properties : cell array of char
%     Property names that define or trigger the rule.
% target_properties : cell array of char
%     Property names referenced by the rule.
% Optional name/value arguments:
%   'source_property'
%       Property from which the rule originated during normalization.
%   'source_choice_group'
%       Choice-group context from which the rule originated.
%   'source_choice_branch'
%       Choice-branch context from which the rule originated.
%   'source_specification'
%       Specification from which the rule originated.
%
% See Also
% --------
% PropertyDefinition
% Specification

    properties (SetAccess=private)
        kind
        subject_properties
        target_properties
        source_property
        source_choice_group
        source_choice_branch
        source_specification
    end

    methods
        function obj = ConstraintRule(kind, subject_properties, target_properties, varargin)
        % Create a specification-level constraint rule.
        %
        % Parameters
        % ----------
        % kind : char
        %     Constraint kind.
        % subject_properties : cell array of char
        %     Subject property names.
        % target_properties : cell array of char
        %     Target property names.
        % Optional name/value arguments:
        %   'source_property'
        %       Property from which the rule originated during normalization.
        %   'source_choice_group'
        %       Choice-group context from which the rule originated.
        %   'source_choice_branch'
        %       Choice-branch context from which the rule originated.
        %   'source_specification'
        %       Specification from which the rule originated.
        %
        % Raises
        % ------
        % error
        %     Raised if the rule kind or property-name collections are invalid.

            valid_kinds = {'requires','paired','all_or_none','exactly_one_of'};

            if ~(ischar(kind) || isstring(kind))
                error('ConstraintRule kind must be a string.');
            end
            kind = char(string(kind));
            if ~ismember(kind, valid_kinds)
                error('ConstraintRule kind "%s" is not valid.', kind);
            end

            if ~iscellstr(subject_properties)
                error('subject_properties must be a cell array of strings.');
            end
            if ~iscellstr(target_properties)
                error('target_properties must be a cell array of strings.');
            end

            p = inputParser;
            addParameter(p, 'source_property', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'source_choice_group', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'source_choice_branch', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'source_specification', '', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});

            obj.kind = kind;
            obj.subject_properties = subject_properties(:).';
            obj.target_properties = target_properties(:).';
            obj.source_property = char(string(p.Results.source_property));
            obj.source_choice_group = char(string(p.Results.source_choice_group));
            obj.source_choice_branch = char(string(p.Results.source_choice_branch));
            obj.source_specification = char(string(p.Results.source_specification));
        end
    end
end