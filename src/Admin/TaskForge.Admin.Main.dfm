object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'TaskForge Admin'
  ClientHeight = 520
  ClientWidth = 920
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  OnCreate = FormCreate
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  TextHeight = 15
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 920
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object EditFilter: TEdit
      Left = 12
      Top = 12
      Width = 320
      Height = 23
      TabOrder = 0
      TextHint = 'Filter tasks...'
      OnChange = EditFilterChange
    end
    object ButtonRefresh: TButton
      Left = 344
      Top = 11
      Width = 90
      Height = 25
      Caption = 'Refresh'
      TabOrder = 1
      OnClick = ButtonRefreshClick
    end
    object ButtonTheme: TButton
      Left = 808
      Top = 11
      Width = 100
      Height = 25
      Caption = 'Toggle Theme'
      TabOrder = 2
      OnClick = ButtonThemeClick
    end
  end
  object ListViewTasks: TListView
    Left = 0
    Top = 48
    Width = 560
    Height = 451
    Align = alLeft
    OwnerData = True
    TabOrder = 1
    ViewStyle = vsReport
    OnData = ListViewTasksData
    OnSelectItem = ListViewTasksSelectItem
  end
  object PanelDetail: TPanel
    Left = 560
    Top = 48
    Width = 360
    Height = 451
    Align = alClient
    BevelOuter = bvLowered
    Padding.Left = 12
    Padding.Top = 12
    Padding.Right = 12
    Padding.Bottom = 12
    TabOrder = 2
    object LabelTitle: TLabel
      Left = 16
      Top = 16
      Width = 23
      Height = 15
      Caption = 'Title'
    end
    object LabelStatus: TLabel
      Left = 16
      Top = 64
      Width = 33
      Height = 15
      Caption = 'Status'
    end
    object LabelDueAt: TLabel
      Left = 16
      Top = 112
      Width = 39
      Height = 15
      Caption = 'Due At'
    end
    object EditTitle: TEdit
      Left = 16
      Top = 32
      Width = 320
      Height = 23
      TabOrder = 0
    end
    object ComboStatus: TComboBox
      Left = 16
      Top = 80
      Width = 160
      Height = 23
      Style = csDropDownList
      TabOrder = 1
    end
    object EditDueAt: TEdit
      Left = 16
      Top = 128
      Width = 320
      Height = 23
      TabOrder = 2
      TextHint = 'YYYY-MM-DDTHH:MM:SSZ'
    end
    object ButtonSave: TButton
      Left = 16
      Top = 168
      Width = 100
      Height = 28
      Caption = 'Save'
      TabOrder = 3
      OnClick = ButtonSaveClick
    end
    object ButtonNew: TButton
      Left = 124
      Top = 168
      Width = 100
      Height = 28
      Caption = 'New'
      TabOrder = 4
      OnClick = ButtonNewClick
    end
    object ButtonDelete: TButton
      Left = 232
      Top = 168
      Width = 104
      Height = 28
      Caption = 'Delete'
      TabOrder = 5
      OnClick = ButtonDeleteClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 499
    Width = 920
    Height = 21
    Panels = <>
    SimplePanel = True
  end
  object DebounceTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = DebounceTimerTimer
    Left = 240
    Top = 8
  end
end
