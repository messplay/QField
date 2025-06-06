/***************************************************************************
  projectinfo.cpp - ProjectInfo

 ---------------------
 begin                : 14.2.2021
 copyright            : (C) 2021 by Mathieu Pellerin
 email                : nirvn dot asia at gmail dot com
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/


#include "projectinfo.h"

#include <QDateTime>
#include <QFileInfo>
#include <QString>
#include <qgslayertree.h>
#include <qgslayertreemodel.h>
#include <qgsmaplayerstyle.h>

ProjectInfo::ProjectInfo( QObject *parent )
  : QObject( parent )
{
  mSaveExtentTimer.setSingleShot( true );
  mSaveRotationTimer.setSingleShot( true );
  mSaveTemporalStateTimer.setSingleShot( true );
  connect( &mSaveExtentTimer, &QTimer::timeout, this, &ProjectInfo::saveExtent );
  connect( &mSaveRotationTimer, &QTimer::timeout, this, &ProjectInfo::saveRotation );
  connect( &mSaveTemporalStateTimer, &QTimer::timeout, this, &ProjectInfo::saveTemporalState );
}

void ProjectInfo::setFilePath( const QString &filePath )
{
  if ( mFilePath == filePath )
    return;

  mFilePath = filePath;

  emit filePathChanged();
  emit stateModeChanged();
  emit activeLayerChanged();
}

QString ProjectInfo::filePath() const
{
  return mFilePath;
}

void ProjectInfo::setMapSettings( QgsQuickMapSettings *mapSettings )
{
  if ( !mapSettings )
    return;

  if ( mMapSettings )
  {
    disconnect( mMapSettings, &QgsQuickMapSettings::extentChanged, this, &ProjectInfo::extentChanged );
    disconnect( mMapSettings, &QgsQuickMapSettings::rotationChanged, this, &ProjectInfo::rotationChanged );
    disconnect( mMapSettings, &QgsQuickMapSettings::temporalStateChanged, this, &ProjectInfo::temporalStateChanged );
  }

  mMapSettings = mapSettings;
  connect( mMapSettings, &QgsQuickMapSettings::extentChanged, this, &ProjectInfo::extentChanged );
  connect( mMapSettings, &QgsQuickMapSettings::rotationChanged, this, &ProjectInfo::rotationChanged );
  connect( mMapSettings, &QgsQuickMapSettings::temporalStateChanged, this, &ProjectInfo::temporalStateChanged );

  emit mapSettingsChanged();
}

QgsQuickMapSettings *ProjectInfo::mapSettings() const
{
  return mMapSettings;
}

void ProjectInfo::setLayerTree( FlatLayerTreeModel *layerTree )
{
  if ( mLayerTree == layerTree )
    return;

  if ( mLayerTree )
  {
    disconnect( mLayerTree, &FlatLayerTreeModel::mapThemeChanged, this, &ProjectInfo::mapThemeChanged );
  }

  mLayerTree = layerTree;

  if ( mLayerTree )
  {
    connect( mLayerTree, &FlatLayerTreeModel::mapThemeChanged, this, &ProjectInfo::mapThemeChanged );
  }

  emit layerTreeChanged();
}

FlatLayerTreeModel *ProjectInfo::layerTree() const
{
  return mLayerTree;
}

void ProjectInfo::setTrackingModel( TrackingModel *trackingModel )
{
  if ( mTrackingModel == trackingModel )
    return;

  mTrackingModel = trackingModel;

  emit trackingModelChanged();
}

TrackingModel *ProjectInfo::trackingModel() const
{
  return mTrackingModel;
}


void ProjectInfo::saveTracker( QgsVectorLayer *layer )
{
  if ( !layer || !mTrackingModel || !mTrackingModel->layerInTracking( layer ) )
    return;

  Tracker *tracker = mTrackingModel->trackerForLayer( layer );

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/trackers/%1" ).arg( layer->id() ) );
  mSettings.setValue( "minimumDistance", tracker->minimumDistance() );
  mSettings.setValue( "timeInterval", tracker->timeInterval() );
  mSettings.setValue( "sensorCapture", tracker->sensorCapture() );
  mSettings.setValue( "conjunction", tracker->conjunction() );
  mSettings.setValue( "maximumDistance", tracker->maximumDistance() );
  mSettings.setValue( "measureType", static_cast<int>( tracker->measureType() ) );
  mSettings.setValue( "visible", tracker->visible() );
  mSettings.setValue( "featureId", tracker->feature().id() );
  mSettings.endGroup();
}

QModelIndex ProjectInfo::restoreTracker( QgsVectorLayer *layer )
{
  if ( !layer || !mTrackingModel || mTrackingModel->layerInTracking( layer ) )
    return QModelIndex();

  if ( !mSettings.contains( QStringLiteral( "/qgis/projectInfo/trackers/%1/minimumDistance" ).arg( layer->id() ) ) )
    return QModelIndex();

  QModelIndex index = mTrackingModel->createTracker( layer );

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/trackers/%1" ).arg( layer->id() ) );
  mTrackingModel->setData( index, mSettings.value( "minimumDistance", 0 ).toDouble(), TrackingModel::MinimumDistance );
  mTrackingModel->setData( index, mSettings.value( "timeInterval", 0 ).toDouble(), TrackingModel::TimeInterval );
  mTrackingModel->setData( index, mSettings.value( "sensorCapture", false ).toBool(), TrackingModel::SensorCapture );
  mTrackingModel->setData( index, mSettings.value( "conjunction", false ).toBool(), TrackingModel::Conjunction );
  mTrackingModel->setData( index, mSettings.value( "maximumDistance", 0 ).toDouble(), TrackingModel::MaximumDistance );
  mTrackingModel->setData( index, static_cast<Tracker::MeasureType>( mSettings.value( "measureType", 0 ).toInt() ), TrackingModel::MeasureType );
  mTrackingModel->setData( index, mSettings.value( "visible", true ).toBool(), TrackingModel::Visible );
  const QgsFeatureId fid = mSettings.value( "featureId", FID_NULL ).toLongLong();
  if ( fid >= 0 )
  {
    QgsFeature feature = layer->getFeature( fid );
    mTrackingModel->setData( index, QVariant::fromValue<QgsFeature>( feature ), TrackingModel::Feature );
  }
  else
  {
    mTrackingModel->setData( index, QVariant::fromValue<QgsFeature>( QgsFeature( layer->fields() ) ), TrackingModel::Feature );
  }
  mSettings.endGroup();

  return index;
}

void ProjectInfo::extentChanged()
{
  mSaveExtentTimer.start( 1000 );
}

void ProjectInfo::saveExtent()
{
  if ( mFilePath.isEmpty() )
    return;

  const QgsRectangle extent = mMapSettings->extent();
  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "extent" ), QStringLiteral( "%1|%2|%3|%4" ).arg( qgsDoubleToString( extent.xMinimum() ), qgsDoubleToString( extent.xMaximum() ), qgsDoubleToString( extent.yMinimum() ), qgsDoubleToString( extent.yMaximum() ) ) );
  mSettings.endGroup();
}

void ProjectInfo::rotationChanged()
{
  mSaveRotationTimer.start( 1000 );
}

void ProjectInfo::saveRotation()
{
  if ( mFilePath.isEmpty() )
    return;

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "rotation" ), mMapSettings->rotation() );
  mSettings.endGroup();
}

void ProjectInfo::temporalStateChanged()
{
  mSaveTemporalStateTimer.start( 1000 );
}

void ProjectInfo::saveTemporalState()
{
  if ( mFilePath.isEmpty() )
    return;

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "isTemporal" ), mMapSettings->isTemporal() );
  mSettings.setValue( QStringLiteral( "StartDateTime" ), mMapSettings->temporalBegin().toTimeSpec( Qt::LocalTime ).toString( Qt::ISODateWithMs ) );
  mSettings.setValue( QStringLiteral( "EndDateTime" ), mMapSettings->temporalEnd().toTimeSpec( Qt::LocalTime ).toString( Qt::ISODateWithMs ) );
  mSettings.endGroup();
}

void ProjectInfo::saveLayerStyle( QgsMapLayer *layer )
{
  if ( mFilePath.isEmpty() || !layer )
    return;

  const bool isDataset = QgsProject::instance()->readBoolEntry( QStringLiteral( "QField" ), QStringLiteral( "isDataset" ), false );
  QgsMapLayerStyle style;
  style.readFromLayer( layer );

  // Prefix id with :: to avoid loss of slash on linux paths
  QString id( QStringLiteral( "::" ) );
  if ( isDataset )
  {
    // For non-project datasets, the layer id is random, use the source URI
    id += layer->source();
  }
  else
  {
    id += layer->id();
  }

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1/layerstyles" ).arg( mFilePath ) );
  mSettings.setValue( id, style.xmlData() );
  mSettings.endGroup();
}

void ProjectInfo::saveLayerTreeState()
{
  if ( mFilePath.isEmpty() || !mLayerTree )
    return;

  const bool isDataset = QgsProject::instance()->readBoolEntry( QStringLiteral( "QField" ), QStringLiteral( "isDataset" ), false );
  if ( !isDataset )
  {
    QgsMapThemeCollection mapCollection( QgsProject::instance() );
    const QgsMapThemeCollection::MapThemeRecord rec = QgsMapThemeCollection::createThemeFromCurrentState( mLayerTree->layerTreeModel()->rootGroup(), mLayerTree->layerTreeModel() );
    mapCollection.insert( QStringLiteral( "::QFieldLayerTreeState" ), rec );

    const QDomDocumentType documentType = QDomImplementation().createDocumentType( QStringLiteral( "qgis" ), QStringLiteral( "http://mrcc.com/qgis.dtd" ), QStringLiteral( "SYSTEM" ) );
    QDomDocument document( documentType );

    document.appendChild( document.createElement( QStringLiteral( "qgis" ) ) );
    mapCollection.writeXml( document );

    mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
    mSettings.setValue( QStringLiteral( "layertreestate" ), document.toString() );
    mSettings.remove( QStringLiteral( "maptheme" ) );
    mSettings.endGroup();
  }
}

void ProjectInfo::saveSnappingConfiguration()
{
  if ( mFilePath.isEmpty() )
    return;

  QgsSnappingConfig config = QgsProject::instance()->snappingConfig();

  const QDomDocumentType documentType = QDomImplementation().createDocumentType( QStringLiteral( "qgis" ), QStringLiteral( "http://mrcc.com/qgis.dtd" ), QStringLiteral( "SYSTEM" ) );
  QDomDocument document( documentType );

  document.appendChild( document.createElement( QStringLiteral( "qgis" ) ) );
  config.writeProject( document );

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "snappingconfig" ), document.toString() );
  mSettings.endGroup();
}

void ProjectInfo::setStateMode( const QString &mode )
{
  if ( mFilePath.isEmpty() )
    return;

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "stateMode" ), mode );
  mSettings.endGroup();
}

QString ProjectInfo::stateMode() const
{
  return mSettings.value( QStringLiteral( "/qgis/projectInfo/%1/stateMode" ).arg( mFilePath ), QStringLiteral( "browse" ) ).toString();
}

void ProjectInfo::setActiveLayer( QgsMapLayer *layer )
{
  if ( mFilePath.isEmpty() || !layer )
    return;

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  mSettings.setValue( QStringLiteral( "activeLayer" ), layer->id() );
  mSettings.endGroup();
}

QgsMapLayer *ProjectInfo::activeLayer() const
{
  const QString layerId = mSettings.value( QStringLiteral( "/qgis/projectInfo/%1/activeLayer" ).arg( mFilePath ) ).toString();
  return !layerId.isEmpty() ? QgsProject::instance()->mapLayer( layerId ) : nullptr;
}

void ProjectInfo::mapThemeChanged()
{
  if ( mFilePath.isEmpty() )
    return;

  mSettings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1" ).arg( mFilePath ) );
  if ( !mLayerTree->mapTheme().isEmpty() )
  {
    mSettings.setValue( QStringLiteral( "maptheme" ), mLayerTree->mapTheme() );
    mSettings.remove( QStringLiteral( "layertreestate" ) );
  }
  else
  {
    mSettings.remove( QStringLiteral( "maptheme" ) );
  }
  mSettings.endGroup();
}

void ProjectInfo::restoreSettings( QString &projectFilePath, QgsProject *project, QgsQuickMapCanvasMap *mapCanvas, FlatLayerTreeModel *layerTree )
{
  QSettings settings;

  const double rotation = settings.value( QStringLiteral( "qgis/projectInfo/%1/rotation" ).arg( projectFilePath ), mapCanvas->mapSettings()->rotation() ).toDouble();
  mapCanvas->mapSettings()->setRotation( rotation );

  const bool isTemporal = settings.value( QStringLiteral( "/qgis/projectInfo/%1/isTemporal" ).arg( projectFilePath ), false ).toBool();
  const QString begin = settings.value( QStringLiteral( "/qgis/projectInfo/%1/StartDateTime" ).arg( projectFilePath ), QString() ).toString();
  const QString end = settings.value( QStringLiteral( "/qgis/projectInfo/%1/EndDateTime" ).arg( projectFilePath ), QString() ).toString();
  if ( !begin.isEmpty() && !end.isEmpty() )
  {
    mapCanvas->mapSettings()->setTemporalBegin( QDateTime::fromString( begin, Qt::ISODateWithMs ) );
    mapCanvas->mapSettings()->setTemporalEnd( QDateTime::fromString( end, Qt::ISODateWithMs ) );
    mapCanvas->mapSettings()->setIsTemporal( isTemporal );
  }

  settings.beginGroup( QStringLiteral( "/qgis/projectInfo/%1/layerstyles" ).arg( projectFilePath ) );
  const QStringList ids = settings.allKeys();
  if ( !ids.isEmpty() )
  {
    const bool isDataset = project->readBoolEntry( QStringLiteral( "QField" ), QStringLiteral( "isDataset" ), false );
    const QList<QgsMapLayer *> mapLayers = isDataset ? project->layerStore()->mapLayers().values() : QList<QgsMapLayer *>();

    for ( QString id : ids )
    {
      const QString xmlData = settings.value( id ).toString();
      if ( xmlData.isEmpty() )
        continue;

      // Remove the :: prefix to get actual layer id or source
      id = id.mid( 2 );

      QgsMapLayer *layer = nullptr;
      if ( isDataset )
      {
        for ( QgsMapLayer *ml : mapLayers )
        {
          if ( ml && ml->source() == id )
          {
            layer = ml;
            break;
          }
        }
      }
      else
      {
        layer = project->layerStore()->mapLayer( id );
      }

      if ( layer )
      {
        QgsMapLayerStyle style( xmlData );
        style.writeToLayer( layer );
      }
    }
  }
  settings.endGroup();

  const QString mapTheme = settings.value( QStringLiteral( "/qgis/projectInfo/%1/maptheme" ).arg( projectFilePath ), QString() ).toString();
  const QString layerTreeState = settings.value( QStringLiteral( "/qgis/projectInfo/%1/layertreestate" ).arg( projectFilePath ), QString() ).toString();
  if ( !mapTheme.isEmpty() )
  {
    layerTree->setMapTheme( mapTheme );
  }
  else if ( !layerTreeState.isEmpty() )
  {
    QDomDocument document;
    document.setContent( layerTreeState );

    QgsMapThemeCollection mapCollection( project );
    mapCollection.readXml( document );
    mapCollection.applyTheme( QStringLiteral( "::QFieldLayerTreeState" ), layerTree->layerTreeModel()->rootGroup(), layerTree->layerTreeModel() );
  }

  const QString snappingConfig = settings.value( QStringLiteral( "/qgis/projectInfo/%1/snappingconfig" ).arg( projectFilePath ), QString() ).toString();
  if ( !snappingConfig.isEmpty() )
  {
    QDomDocument document;
    document.setContent( snappingConfig );

    QgsSnappingConfig config( project );
    config.readProject( document );
    project->setSnappingConfig( config );
  }
}
