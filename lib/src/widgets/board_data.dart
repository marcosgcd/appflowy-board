import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:equatable/equatable.dart';

import 'package:appflowy_board/src/widgets/board_group/group_data.dart';

import '../utils/log.dart';

import 'reorder_flex/reorder_flex.dart';
import 'reorder_phantom/phantom_controller.dart';

typedef OnMoveGroup = void Function(
  String fromGroupId,
  int fromIndex,
  String toGroupId,
  int toIndex,
);

typedef OnMoveGroupItem = void Function(
  String groupId,
  int fromIndex,
  int toIndex,
);

typedef OnMoveGroupItemToGroup = void Function(
  String fromGroupId,
  int fromIndex,
  String toGroupId,
  int toIndex,
);

typedef OnStartDraggingCard = void Function(
  String groupId,
  int index,
);

/// A controller for [AppFlowyBoard] widget.
///
/// A [AppFlowyBoardController] can be used to provide an initial value of
/// the board by calling `addGroup` method with the passed in parameter
/// [AppFlowyGroupData]. A [AppFlowyGroupData] represents one
/// group data. Whenever the user modifies the board, this controller will
/// update the corresponding group data.
///
/// Also, you can register the callbacks that receive the changes.
/// [onMoveGroup] will get called when moving the group from one position to
/// another.
///
/// [onMoveGroupItem] will get called when moving the group's items.
///
/// [onMoveGroupItemToGroup] will get called when moving the group's item from
/// one group to another group.
class AppFlowyBoardController extends ChangeNotifier
    with EquatableMixin
    implements BoardPhantomControllerDelegate, ReoderFlexDataSource {
  AppFlowyBoardController({
    this.onMoveGroup,
    this.onMoveGroupItem,
    this.onMoveGroupItemToGroup,
    this.onStartDraggingCard,
  });

  final List<AppFlowyGroupData> _groupDatas = [];

  /// [onMoveGroup] will get called when moving the group from one position to
  /// another.
  final OnMoveGroup? onMoveGroup;

  /// [onMoveGroupItem] will get called when moving the group's items.
  final OnMoveGroupItem? onMoveGroupItem;

  /// [onMoveGroupItemToGroup] will get called when moving the group's item from
  /// one group to another group.
  final OnMoveGroupItemToGroup? onMoveGroupItemToGroup;

  final OnStartDraggingCard? onStartDraggingCard;

  /// Returns the unmodifiable list of [AppFlowyGroupData]
  UnmodifiableListView<AppFlowyGroupData> get groupDatas =>
      UnmodifiableListView(_groupDatas);

  /// Returns list of group id
  List<String> get groupIds =>
      _groupDatas.map((groupData) => groupData.id).toList();

  final LinkedHashMap<String, AppFlowyGroupController> _groupControllers =
      LinkedHashMap();

  /// Adds a new group to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding a new group, the
  /// [notify] should set to false. Default value is true.
  void addGroup(AppFlowyGroupData groupData, {bool notify = true}) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = AppFlowyGroupController(groupData: groupData);
    _groupDatas.add(groupData);
    _groupControllers[groupData.id] = controller;
    if (notify) notifyListeners();
  }

  /// Inserts a new group at the given index
  ///
  /// If you don't want to notify the listener after inserting the new group, the
  /// [notify] should set to false. Default value is true.
  void insertGroup(
    int index,
    AppFlowyGroupData groupData, {
    bool notify = true,
  }) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = AppFlowyGroupController(groupData: groupData);
    _groupDatas.insert(index, groupData);
    _groupControllers[groupData.id] = controller;
    if (notify) notifyListeners();
  }

  /// Adds a list of groups to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding the groups, the
  /// [notify] should set to false. Default value is true.
  void addGroups(List<AppFlowyGroupData> groups, {bool notify = true}) {
    for (final column in groups) {
      addGroup(column, notify: false);
    }

    if (groups.isNotEmpty && notify) notifyListeners();
  }

  /// Adds a list of groups to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding the groups, the
  /// [notify] should set to false. Default value is true.
  void setGroups(List<AppFlowyGroupData> groups) {
    bool notify = false;
    notify = notify || _groupDatas.length != groups.length;

    // Create a map from group IDs to group data for quick access
    final groupMap = {for (final group in groups) group.id: group};

    // Remove groups from _groupDatas that are not in the new groups
    _groupDatas.removeWhere((group) => !groupMap.containsKey(group.id));

    // Update existing groups and add new ones
    for (final group in groups) {
      final groupIndex = _groupDatas.indexWhere((g) => g.id == group.id);

      if (groupIndex == -1) {
        // If the group doesn't exist, add it
        _groupDatas.add(group);
      }

      // Update or create group controllers
      _groupControllers[group.id] = _groupControllers[group.id] ??
          AppFlowyGroupController(groupData: group);

      _groupControllers[group.id]!.replaceOrInsertAll(group.items);
    }

    final groupDataOrder = _groupDatas.map((group) => group.id).join(",");
    final groupsOrder = groups.map((group) => group.id).join(",");

    if (groupDataOrder != groupsOrder) {
      notify = notify || true;
      // Sort _groupDatas to match the order of groups
      _groupDatas.sort((a, b) {
        final indexA = groups.indexWhere((g) => g.id == a.id);
        final indexB = groups.indexWhere((g) => g.id == b.id);
        return indexA.compareTo(indexB);
      });
    }

    // Remove controllers that are no longer needed
    final newGroupIds = groupMap.keys.toSet();
    _groupControllers.removeWhere((groupId, controller) {
      if (!newGroupIds.contains(groupId)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    if (notify) {
      notifyListeners();
    }
  }

  /// Removes the group with id [groupId]
  ///
  /// If you don't want to notify the listener after removing the group, the
  /// [notify] should set to false. Default value is true.
  void removeGroup(String groupId, {bool notify = true}) {
    final index = _groupDatas.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      Log.warn(
        'Try to remove Group:[$groupId] failed. Group:[$groupId] does not exist',
      );
    }

    if (index != -1) {
      _groupDatas.removeAt(index);
      _groupControllers.remove(groupId);

      if (notify) notifyListeners();
    }
  }

  /// Removes a list of groups
  ///
  /// If you don't want to notify the listener after removing the groups, the
  /// [notify] should set to false. Default value is true.
  void removeGroups(List<String> groupIds, {bool notify = true}) {
    for (final groupId in groupIds) {
      removeGroup(groupId, notify: false);
    }

    if (groupIds.isNotEmpty && notify) notifyListeners();
  }

  /// Remove all the groups controller.
  ///
  /// This method should get called when you want to remove all the current
  /// groups or get ready to reinitialize the [AppFlowyBoard].
  void clear() {
    _groupDatas.clear();
    for (final group in _groupControllers.values) {
      group.dispose();
    }
    _groupControllers.clear();

    notifyListeners();
  }

  /// Returns the [AppFlowyGroupController] with id [groupId].
  AppFlowyGroupController? getGroupController(String groupId) {
    final groupController = _groupControllers[groupId];
    if (groupController == null) {
      Log.warn('Group:[$groupId] \'s controller is not exist');
    }

    return groupController;
  }

  /// Moves the group controller from [fromIndex] to [toIndex] and notify the
  /// listeners.
  ///
  /// If you don't want to notify the listener after moving the group, the
  /// [notify] should set to false. Default value is true.
  void moveGroup(int fromIndex, int toIndex, {bool notify = true}) {
    final toGroupData = _groupDatas[toIndex];
    final fromGroupData = _groupDatas.removeAt(fromIndex);

    _groupDatas.insert(toIndex, fromGroupData);
    onMoveGroup?.call(fromGroupData.id, fromIndex, toGroupData.id, toIndex);
    if (notify) notifyListeners();
  }

  /// Moves the group's item from [fromIndex] to [toIndex]
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void moveGroupItem(String groupId, int fromIndex, int toIndex) {
    if (getGroupController(groupId)?.move(fromIndex, toIndex) ?? false) {
      onMoveGroupItem?.call(groupId, fromIndex, toIndex);
    }
  }

  /// Adds the [AppFlowyGroupItem] to the end of the group
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void addGroupItem(String groupId, AppFlowyGroupItem item) {
    getGroupController(groupId)?.add(item);
  }

  /// Inserts the [AppFlowyGroupItem] at [index] in the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void insertGroupItem(String groupId, int index, AppFlowyGroupItem item) {
    getGroupController(groupId)?.insert(index, item);
  }

  /// Removes the item with id [itemId] from the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void removeGroupItem(String groupId, String itemId) {
    getGroupController(groupId)?.removeWhere((item) => item.id == itemId);
  }

  /// Replaces or inserts the [AppFlowyGroupItem] to the end of the group.
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void updateGroupItem(String groupId, AppFlowyGroupItem item) {
    getGroupController(groupId)?.replaceOrInsertItem(item);
  }

  void enableGroupDragging(bool isEnable) {
    for (final groupController in _groupControllers.values) {
      groupController.enableDragging(isEnable);
    }
  }

  /// Moves the item at [fromGroupIndex] in group with id [fromGroupId] to
  /// group with id [toGroupId] at [toGroupIndex]
  @override
  @protected
  void moveGroupItemToAnotherGroup(
    String fromGroupId,
    int fromGroupIndex,
    String toGroupId,
    int toGroupIndex,
  ) {
    final fromGroupController = getGroupController(fromGroupId)!;
    final toGroupController = getGroupController(toGroupId)!;
    final fromGroupItem = fromGroupController.removeAt(fromGroupIndex);
    if (fromGroupItem == null) return;

    if (toGroupController.items.length > toGroupIndex) {
      assert(toGroupController.items[toGroupIndex] is PhantomGroupItem);

      toGroupController.replace(toGroupIndex, fromGroupItem);
      onMoveGroupItemToGroup?.call(
        fromGroupId,
        fromGroupIndex,
        toGroupId,
        toGroupIndex,
      );
    }
  }

  @override
  List<Object?> get props => [_groupDatas];

  @override
  AppFlowyGroupController? controller(String groupId) =>
      _groupControllers[groupId];

  @override
  String get identifier => '$AppFlowyBoardController';

  @override
  UnmodifiableListView<ReoderFlexItem> get items =>
      UnmodifiableListView(_groupDatas);

  @override
  @protected
  bool removePhantom(String groupId) {
    final groupController = getGroupController(groupId);
    if (groupController == null) {
      Log.warn('Can not find the group controller with groupId: $groupId');
      return false;
    }
    final index = groupController.items.indexWhere((item) => item.isPhantom);
    final isExist = index != -1;
    if (isExist) {
      groupController.removeAt(index);

      Log.debug(
        '[$AppFlowyBoardController] Group:[$groupId] remove phantom, current count: ${groupController.items.length}',
      );
    }
    return isExist;
  }

  @override
  @protected
  void updatePhantom(String groupId, int newIndex) {
    final groupController = getGroupController(groupId)!;
    final index = groupController.items.indexWhere((item) => item.isPhantom);

    if (index != -1) {
      if (index != newIndex) {
        Log.trace(
          '[$BoardPhantomController] update $groupId:$index to $groupId:$newIndex',
        );
        final item = groupController.removeAt(index, notify: false);
        if (item != null) {
          groupController.insert(newIndex, item, notify: false);
        }
      }
    }
  }

  @override
  @protected
  void insertPhantom(String groupId, int index, PhantomGroupItem item) =>
      getGroupController(groupId)!.insert(index, item);
}
