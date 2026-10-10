"""Explicit comparison projection for additive dispatch/portal authoring metadata.

Only these new fields are removed. Gameplay maps, groups, exact queue bytes and
numeric types remain subject to the unchanged historical baseline oracle.
"""
import copy


def without_dispatch_metadata(value):
    result = copy.deepcopy(value)
    if isinstance(result, dict):
        result.pop('schedulingPolicy', None)
        result.pop('groupDispatch', None)
        if 'stages' in result:
            result['stages'] = [without_dispatch_metadata(s) for s in result['stages']]
        if 'waves' in result:
            result['waves'] = [without_dispatch_metadata(w) for w in result['waves']]
        if 'groups' in result:
            for group in result['groups']: group.pop('id', None)
        if 'map' in result:
            result['map'] = without_dispatch_metadata(result['map'])
        if 'tiles' in result and 'path' in result:
            result.pop('spawnPortals', None)
            for route in result.get('routes', []): route.pop('spawnPortalId', None)
    return result
