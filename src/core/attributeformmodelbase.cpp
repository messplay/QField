/***************************************************************************
  attributeformmodelbase.cpp - AttributeFormModelBase

 ---------------------
 begin                : 16.8.2016
 copyright            : (C) 2016 by Matthias Kuhn
 email                : matthias@opengis.ch
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "attributeformmodel.h"
#include "attributeformmodelbase.h"

#include <QRegularExpression>
#include <qgsattributeeditorelement.h>
#include <qgsattributeeditorfield.h>
#include <qgsattributeeditorhtmlelement.h>
#include <qgsattributeeditorqmlelement.h>
#include <qgsattributeeditorrelation.h>
#include <qgsattributeeditortextelement.h>
#include <qgsdatetimefieldformatter.h>
#include <qgseditorwidgetsetup.h>
#include <qgsmapthemecollection.h>
#include <qgsproject.h>
#include <qgsrelationmanager.h>
#include <qgsvectorlayer.h>
#include <qgsvectorlayerutils.h>


AttributeFormModelBase::AttributeFormModelBase( QObject *parent )
  : QStandardItemModel( 0, 1, parent )
{
  connect( QgsProject::instance(), &QgsProject::mapThemeCollectionChanged, this, &AttributeFormModelBase::onMapThemeCollectionChanged );
  if ( QgsProject::instance()->mapThemeCollection() )
    onMapThemeCollectionChanged();
}

void AttributeFormModelBase::onMapThemeCollectionChanged()
{
  connect( QgsProject::instance()->mapThemeCollection(), &QgsMapThemeCollection::mapThemeChanged, this, [=] { resetModel(); applyFeatureModel(); } );
}

QHash<int, QByteArray> AttributeFormModelBase::roleNames() const
{
  QHash<int, QByteArray> roles = QAbstractItemModel::roleNames();

  roles[AttributeFormModel::ElementType] = "Type";
  roles[AttributeFormModel::Name] = "Name";
  roles[AttributeFormModel::AttributeValue] = "AttributeValue";
  roles[AttributeFormModel::AttributeEditable] = "AttributeEditable";
  roles[AttributeFormModel::EditorWidget] = "EditorWidget";
  roles[AttributeFormModel::EditorWidgetConfig] = "EditorWidgetConfig";
  roles[AttributeFormModel::RelationEditorWidget] = "RelationEditorWidget";
  roles[AttributeFormModel::RelationEditorWidgetConfig] = "RelationEditorWidgetConfig";
  roles[AttributeFormModel::RememberValue] = "RememberValue";
  roles[AttributeFormModel::Field] = "Field";
  roles[AttributeFormModel::RelationId] = "RelationId";
  roles[AttributeFormModel::NmRelationId] = "NmRelationId";
  roles[AttributeFormModel::ConstraintHardValid] = "ConstraintHardValid";
  roles[AttributeFormModel::ConstraintSoftValid] = "ConstraintSoftValid";
  roles[AttributeFormModel::ConstraintDescription] = "ConstraintDescription";
  roles[AttributeFormModel::AttributeAllowEdit] = "AttributeAllowEdit";
  roles[AttributeFormModel::EditorWidgetCode] = "EditorWidgetCode";
  roles[AttributeFormModel::TabIndex] = "TabIndex";
  roles[AttributeFormModel::GroupColor] = "GroupColor";
  roles[AttributeFormModel::GroupName] = "GroupName";
  roles[AttributeFormModel::GroupIndex] = "GroupIndex";
  roles[AttributeFormModel::ColumnCount] = "ColumnCount";
  roles[AttributeFormModel::LabelOverrideColor] = "LabelOverrideColor";
  roles[AttributeFormModel::LabelColor] = "LabelColor";
  roles[AttributeFormModel::LabelOverrideFont] = "LabelOverrideFont";
  roles[AttributeFormModel::LabelFont] = "LabelFont";

  return roles;
}

bool AttributeFormModelBase::setData( const QModelIndex &index, const QVariant &value, int role )
{
  QStandardItem *item = itemFromIndex( index );
  if ( !item )
    return false;

  if ( !qgsVariantEqual( data( index, role ), value ) )
  {
    switch ( role )
    {
      case AttributeFormModel::AttributeAllowEdit:
      {
        int fieldIndex = item->data( AttributeFormModel::FieldIndex ).toInt();
        mFeatureModel->setData( mFeatureModel->index( fieldIndex ), value, FeatureModel::AttributeAllowEdit );
        item->setData( value, AttributeFormModel::AttributeAllowEdit );
        updateVisibilityAndConstraints( fieldIndex );
        break;
      }

      case AttributeFormModel::RememberValue:
      {
        int fieldIndex = item->data( AttributeFormModel::FieldIndex ).toInt();
        mFeatureModel->setData( mFeatureModel->index( fieldIndex ), value, FeatureModel::RememberAttribute );
        item->setData( value, AttributeFormModel::RememberValue );
        break;
      }

      case AttributeFormModel::AttributeValue:
      {
        int fieldIndex = item->data( AttributeFormModel::FieldIndex ).toInt();
        bool changed = mFeatureModel->setData( mFeatureModel->index( fieldIndex ), value, FeatureModel::AttributeValue );
        if ( changed )
        {
          synchronizeFieldValue( fieldIndex, value );
        }
        updateDefaultValues( fieldIndex );
        updateVisibilityAndConstraints( fieldIndex );
        return changed;
      }
    }
  }
  return false;
}

FeatureModel *AttributeFormModelBase::featureModel() const
{
  return mFeatureModel;
}

void AttributeFormModelBase::setFeatureModel( FeatureModel *featureModel )
{
  if ( mFeatureModel == featureModel )
    return;

  if ( mFeatureModel )
  {
    disconnect( mFeatureModel, &FeatureModel::currentLayerChanged, this, &AttributeFormModelBase::resetModel );
    disconnect( mFeatureModel, &FeatureModel::modelReset, this, &AttributeFormModelBase::applyFeatureModel );
    disconnect( mFeatureModel, &FeatureModel::featureUpdated, this, &AttributeFormModelBase::applyFeatureModel );
  }

  mFeatureModel = featureModel;

  connect( mFeatureModel, &FeatureModel::currentLayerChanged, this, &AttributeFormModelBase::resetModel );
  connect( mFeatureModel, &FeatureModel::modelReset, this, &AttributeFormModelBase::applyFeatureModel );
  connect( mFeatureModel, &FeatureModel::featureUpdated, this, &AttributeFormModelBase::applyFeatureModel );

  emit featureModelChanged();
}

void AttributeFormModelBase::resetModel()
{
  clear();

  mVisibilityExpressions.clear();
  mConstraints.clear();
  mEditorWidgetCodes.clear();

  setHasTabs( false );

  if ( !mFeatureModel )
    return;

  mLayer = mFeatureModel->layer();

  if ( mLayer )
  {
    QgsAttributeEditorContainer *root;
#if _QGIS_VERSION_INT >= 33100
    if ( mLayer->editFormConfig().layout() == Qgis::AttributeFormLayout::DragAndDrop )
#else
    if ( mLayer->editFormConfig().layout() == QgsEditFormConfig::TabLayout )
#endif
    {
      root = mLayer->editFormConfig().invisibleRootContainer();
      mTemporaryContainer.reset();
    }
    else
    {
      root = generateRootContainer();
      mTemporaryContainer.reset( root );
    }

#if _QGIS_VERSION_INT >= 33100
    const bool hasTabs = !root->children().isEmpty() && Qgis::AttributeEditorType::Container == root->children().first()->type();
#else
    const bool hasTabs = !root->children().isEmpty() && QgsAttributeEditorElement::AeTypeContainer == root->children().first()->type();
#endif

    invisibleRootItem()->setColumnCount( 1 );
    QList<QStandardItem *> containers;
    if ( hasTabs )
    {
      const QList<QgsAttributeEditorElement *> children { root->children() };
      int currentTab = 0;
      for ( QgsAttributeEditorElement *element : children )
      {
#if _QGIS_VERSION_INT >= 33100
        if ( element->type() == Qgis::AttributeEditorType::Container )
#else
        if ( element->type() == QgsAttributeEditorElement::AeTypeContainer )
#endif
        {
          QgsAttributeEditorContainer *container = static_cast<QgsAttributeEditorContainer *>( element );
          const int columnCount = container->columnCount();

          QStandardItem *item = new QStandardItem();
          item->setData( element->name(), AttributeFormModel::Name );
          item->setData( "container", AttributeFormModel::ElementType );
          item->setData( QString(), AttributeFormModel::GroupName );
          item->setData( QModelIndex(), AttributeFormModel::GroupIndex );
          item->setData( true, AttributeFormModel::CurrentlyVisible );
          item->setData( true, AttributeFormModel::ConstraintHardValid );
          item->setData( true, AttributeFormModel::ConstraintSoftValid );

          QString visibilityExpression;
          if ( container->visibilityExpression().enabled() )
          {
            mVisibilityExpressions.append( qMakePair( container->visibilityExpression().data(), item ) );
            visibilityExpression = container->visibilityExpression().data().expression();
          }

          buildForm( container, item, visibilityExpression, containers, currentTab, columnCount );
          invisibleRootItem()->appendRow( item );
          setHasTabs( true );
          currentTab++;
        }
      }
    }
    else
    {
      buildForm( invisibleRootContainer(), invisibleRootItem(), QString(), containers );
    }

    for ( QStandardItem *container : std::as_const( containers ) )
    {
      container->setData( container->index(), AttributeFormModel::GroupIndex );
    }
  }
}

void AttributeFormModelBase::applyFeatureModel()
{
  mExpressionContext = mFeatureModel->createExpressionContext();
  for ( int i = 0; i < invisibleRootItem()->rowCount(); ++i )
  {
    updateAttributeValue( invisibleRootItem()->child( i ) );
  }
  updateVisibilityAndConstraints();
}

QgsAttributeEditorContainer *AttributeFormModelBase::generateRootContainer() const
{
  QgsAttributeEditorContainer *root = new QgsAttributeEditorContainer( QString(), nullptr );
  //get fields
  QgsFields fields = mLayer->fields();
  for ( int i = 0; i < fields.size(); ++i )
  {
    if ( fields.at( i ).editorWidgetSetup().type() != QStringLiteral( "Hidden" ) )
    {
      QgsAttributeEditorField *field = new QgsAttributeEditorField( fields.at( i ).name(), i, root );
      root->addChildElement( field );
    }
  }
  //get relations
  const QList<QgsRelation> referencingRelations = QgsProject::instance()->relationManager()->referencedRelations( mLayer );
  for ( const QgsRelation &referencingRelation : referencingRelations )
  {
    QgsAttributeEditorRelation *relation = new QgsAttributeEditorRelation( referencingRelation, root );
    root->addChildElement( relation );
  }
  return root;
}

QgsAttributeEditorContainer *AttributeFormModelBase::invisibleRootContainer() const
{
  return mTemporaryContainer ? mTemporaryContainer.get() : mLayer->editFormConfig().invisibleRootContainer();
}

void AttributeFormModelBase::updateAttributeValue( QStandardItem *item )
{
  if ( item->data( AttributeFormModel::ElementType ) == QStringLiteral( "field" ) )
  {
    int fieldIndex = item->data( AttributeFormModel::FieldIndex ).toInt();
    QVariant attributeValue = mFeatureModel->data( mFeatureModel->index( fieldIndex ), FeatureModel::AttributeValue );
    item->setData( attributeValue.isNull() ? QVariant() : attributeValue, AttributeFormModel::AttributeValue );
    item->setData( mFeatureModel->data( mFeatureModel->index( fieldIndex ), FeatureModel::AttributeAllowEdit ), AttributeFormModel::AttributeAllowEdit );
    // set item editable state to false in case it's a linked attribute
    if ( mFeatureModel->data( mFeatureModel->index( fieldIndex ), FeatureModel::LinkedAttribute ).toBool() )
    {
      item->setData( false, AttributeFormModel::AttributeEditable );
    }
  }
  else if ( item->data( AttributeFormModel::ElementType ) == QStringLiteral( "qml" ) || item->data( AttributeFormModel::ElementType ) == QStringLiteral( "html" ) )
  {
    QString code = mEditorWidgetCodes[item];

    QRegularExpression re( "expression\\.evaluate\\(\\s*\\\"(.*?[^\\\\])\\\"\\s*\\)" );
    QRegularExpressionMatch match = re.match( code );
    while ( match.hasMatch() )
    {
      QString expression = match.captured( 1 );
      expression = expression.replace( QStringLiteral( "\\\"" ), QStringLiteral( "\"" ) );

      mExpressionContext.setFeature( mFeatureModel->feature() );

      QgsExpression exp = QgsExpression( expression );
      exp.prepare( &mExpressionContext );
      QVariant result = exp.evaluate( &mExpressionContext );

      QString resultString;
      switch ( static_cast<QMetaType::Type>( result.type() ) )
      {
        case QMetaType::Int:
        case QMetaType::UInt:
        case QMetaType::Double:
        case QMetaType::LongLong:
        case QMetaType::ULongLong:
          resultString = result.toString();
          break;
        case QMetaType::Bool:
          resultString = result.toBool() ? QStringLiteral( "true" ) : QStringLiteral( "false" );
          break;
        default:
          resultString = QStringLiteral( "'%1'" ).arg( result.toString() );
          break;
      }
      code = code.mid( 0, match.capturedStart( 0 ) ) + resultString + code.mid( match.capturedEnd( 0 ) );
      match = re.match( code );
    }
    item->setData( code, AttributeFormModel::EditorWidgetCode );
  }
  else if ( item->data( AttributeFormModel::ElementType ) == QStringLiteral( "text" ) )
  {
    QString code = mEditorWidgetCodes[item];

    mExpressionContext.setFeature( mFeatureModel->feature() );
    code = QgsExpression::replaceExpressionText( code, &mExpressionContext );
    item->setData( code, AttributeFormModel::EditorWidgetCode );
  }
  else
  {
    for ( int i = 0; i < item->rowCount(); ++i )
    {
      updateAttributeValue( item->child( i ) );
    }
  }
}

void AttributeFormModelBase::buildForm( QgsAttributeEditorContainer *container, QStandardItem *parent, const QString &parentVisibilityExpressions, QList<QStandardItem *> &containers, int currentTabIndex, int columnCount )
{
  const QList<QgsAttributeEditorElement *> children { container->children() };
  for ( QgsAttributeEditorElement *element : children )
  {
    QStandardItem *item = new QStandardItem();
    item->setData( columnCount, AttributeFormModel::ColumnCount );
    item->setData( currentTabIndex, AttributeFormModel::TabIndex );
    item->setData( QString(), AttributeFormModel::GroupName );
    item->setData( QModelIndex(), AttributeFormModel::GroupIndex );
    item->setData( true, AttributeFormModel::ConstraintHardValid );
    item->setData( true, AttributeFormModel::ConstraintSoftValid );

    QgsAttributeEditorElement::LabelStyle labelStyle = element->labelStyle();
    item->setData( labelStyle.overrideColor, AttributeFormModel::LabelOverrideColor );
    item->setData( labelStyle.overrideColor ? labelStyle.color : QColor(), AttributeFormModel::LabelColor );
    item->setData( labelStyle.overrideFont, AttributeFormModel::LabelOverrideFont );
    item->setData( labelStyle.overrideFont ? labelStyle.font : QFont(), AttributeFormModel::LabelFont );

    switch ( element->type() )
    {
#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::Container:
#else
      case QgsAttributeEditorElement::AeTypeContainer:
#endif
      {
        QString visibilityExpression = parentVisibilityExpressions;
        QgsAttributeEditorContainer *innerContainer = static_cast<QgsAttributeEditorContainer *>( element );
        const int innerColumnCount = innerContainer->columnCount();
        if ( innerContainer->visibilityExpression().enabled() )
        {
          if ( visibilityExpression.isNull() )
            visibilityExpression = innerContainer->visibilityExpression().data().expression();
          else
            visibilityExpression += " AND " + innerContainer->visibilityExpression().data().expression();
        }

        item->setData( "container", AttributeFormModel::ElementType );
        item->setData( innerContainer->name(), AttributeFormModel::Name );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( false, AttributeFormModel::AttributeEditable );
        item->setData( false, AttributeFormModel::AttributeAllowEdit );
        item->setData( innerContainer->name(), AttributeFormModel::GroupName );
        if ( innerContainer->backgroundColor().isValid() )
          item->setData( innerContainer->backgroundColor(), AttributeFormModel::GroupColor );

        buildForm( innerContainer, item, visibilityExpression, containers, 0, innerColumnCount );
        parent->appendRow( item );
        containers << item;

        if ( !visibilityExpression.isEmpty() )
          mVisibilityExpressions.append( qMakePair( QgsExpression( visibilityExpression ), item ) );
        break;
      }

#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::Field:
#else
      case QgsAttributeEditorElement::AeTypeField:
#endif
      {
        QgsAttributeEditorField *editorField = static_cast<QgsAttributeEditorField *>( element );

        // editorField->idx() is not working on joined fields
        const QgsFields fields = mLayer->fields();
        int fieldIndex = fields.lookupField( editorField->name() );

        if ( fieldIndex < 0 || fieldIndex >= mLayer->fields().size() )
          continue;

        QgsField field = mLayer->fields().at( fieldIndex );

        item->setData( mLayer->attributeDisplayName( fieldIndex ), AttributeFormModel::Name );
        item->setData( !mLayer->editFormConfig().readOnly( fieldIndex ), AttributeFormModel::AttributeEditable );
        const QgsEditorWidgetSetup setup = findBest( fieldIndex );
        item->setData( setup.type(), AttributeFormModel::EditorWidget );
        item->setData( setup.config(), AttributeFormModel::EditorWidgetConfig );
        item->setData( mFeatureModel->rememberedAttributes().at( fieldIndex ) ? Qt::Checked : Qt::Unchecked, AttributeFormModel::RememberValue );
        item->setData( QgsField( field ), AttributeFormModel::Field );
        item->setData( "field", AttributeFormModel::ElementType );
        item->setData( fieldIndex, AttributeFormModel::FieldIndex );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( mFeatureModel->data( mFeatureModel->index( fieldIndex ), FeatureModel::AttributeAllowEdit ), AttributeFormModel::AttributeAllowEdit );

        // create constraint description
        QStringList descriptions;
        if ( field.constraints().constraints() & QgsFieldConstraints::ConstraintExpression )
        {
          descriptions << ( !field.constraints().constraintDescription().isEmpty()
                              ? field.constraints().constraintDescription()
                              : tr( "Expression constraint" ) );
        }
        if ( field.constraints().constraints() & QgsFieldConstraints::ConstraintNotNull )
        {
          descriptions << tr( "Not NULL" );
        }
        if ( field.constraints().constraints() & QgsFieldConstraints::ConstraintUnique )
        {
          descriptions << tr( "Unique" );
        }

        item->setData( descriptions.join( ", " ), AttributeFormModel::ConstraintDescription );

        updateAttributeValue( item );

        mConstraints.insert( item, field.constraints() );

        parent->appendRow( item );
        break;
      }

#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::Relation:
#else
      case QgsAttributeEditorElement::AeTypeRelation:
#endif
      {
        QgsAttributeEditorRelation *editorRelation = static_cast<QgsAttributeEditorRelation *>( element );
        QgsRelation relation = editorRelation->relation();

        item->setData( !editorRelation->label().isEmpty() ? editorRelation->label() : relation.name(), AttributeFormModel::Name );
        item->setData( true, AttributeFormModel::AttributeEditable );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( "relation", AttributeFormModel::ElementType );
        item->setData( "RelationEditor", AttributeFormModel::EditorWidget );
        item->setData( editorRelation->relationWidgetTypeId(), AttributeFormModel::RelationEditorWidget );
        item->setData( editorRelation->relationEditorConfiguration(), AttributeFormModel::RelationEditorWidgetConfig );
        item->setData( relation.id(), AttributeFormModel::RelationId );
        item->setData( mLayer->editFormConfig().widgetConfig( relation.id() )[QStringLiteral( "nm-rel" )].toString(), AttributeFormModel::NmRelationId );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( true, AttributeFormModel::ConstraintHardValid );
        item->setData( true, AttributeFormModel::ConstraintSoftValid );
        item->setData( true, AttributeFormModel::AttributeAllowEdit );

        parent->appendRow( item );
        break;
      }

#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::QmlElement:
#else
      case QgsAttributeEditorElement::AeTypeQmlElement:
#endif
      {
        QgsAttributeEditorQmlElement *qmlElement = static_cast<QgsAttributeEditorQmlElement *>( element );

        item->setData( "qml", AttributeFormModel::ElementType );
        item->setData( qmlElement->name(), AttributeFormModel::Name );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( false, AttributeFormModel::AttributeEditable );
        item->setData( false, AttributeFormModel::AttributeAllowEdit );


        updateAttributeValue( item );
        parent->appendRow( item );
        mEditorWidgetCodes.insert( item, qmlElement->qmlCode() );
        break;
      }

#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::HtmlElement:
#else
      case QgsAttributeEditorElement::AeTypeHtmlElement:
#endif
      {
        QgsAttributeEditorHtmlElement *htmlElement = static_cast<QgsAttributeEditorHtmlElement *>( element );

        item->setData( "html", AttributeFormModel::ElementType );
        item->setData( htmlElement->name(), AttributeFormModel::Name );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( false, AttributeFormModel::AttributeEditable );
        item->setData( false, AttributeFormModel::AttributeAllowEdit );

        updateAttributeValue( item );
        parent->appendRow( item );
        mEditorWidgetCodes.insert( item, htmlElement->htmlCode() );
        break;
      }

#if _QGIS_VERSION_INT >= 33100
      case Qgis::AttributeEditorType::TextElement:
      {
        QgsAttributeEditorTextElement *textElement = static_cast<QgsAttributeEditorTextElement *>( element );

        item->setData( "text", AttributeFormModel::ElementType );
        item->setData( textElement->name(), AttributeFormModel::Name );
        item->setData( true, AttributeFormModel::CurrentlyVisible );
        item->setData( false, AttributeFormModel::AttributeEditable );
        item->setData( false, AttributeFormModel::AttributeAllowEdit );

        updateAttributeValue( item );
        parent->appendRow( item );
        mEditorWidgetCodes.insert( item, textElement->text() );
        break;
      }
      case Qgis::AttributeEditorType::Action:
      case Qgis::AttributeEditorType::SpacerElement:
      case Qgis::AttributeEditorType::Invalid:
#else
      case QgsAttributeEditorElement::AeTypeInvalid:
      case QgsAttributeEditorElement::AeTypeAction:
#endif
        // TODO: implement
        delete item;
        break;
    }
  }
}

void AttributeFormModelBase::synchronizeFieldValue( int fieldIndex, QVariant value )
{
  QMap<QStandardItem *, QgsFieldConstraints>::ConstIterator constraintIterator( mConstraints.constBegin() );
  for ( ; constraintIterator != mConstraints.constEnd(); ++constraintIterator )
  {
    QStandardItem *item = constraintIterator.key();
    const int fidx = item->data( AttributeFormModel::FieldIndex ).toInt();
    if ( fidx != fieldIndex )
      continue;

    item->setData( value, AttributeFormModel::AttributeValue );
  }
}

void AttributeFormModelBase::updateDefaultValues( int fieldIndex, QVector<int> updatedFields )
{
  const QgsFields fields = mFeatureModel->feature().fields();
  if ( fieldIndex < 0 || fieldIndex >= fields.size() )
    return;
  const QString fieldName = fields.at( fieldIndex ).name();

  mExpressionContext.setFields( fields );
  mExpressionContext.setFeature( mFeatureModel->feature() );

  QMap<QStandardItem *, QgsFieldConstraints>::ConstIterator constraintIterator( mConstraints.constBegin() );
  for ( ; constraintIterator != mConstraints.constEnd(); ++constraintIterator )
  {
    QStandardItem *item = constraintIterator.key();
    const int fidx = item->data( AttributeFormModel::FieldIndex ).toInt();
    if ( fidx == fieldIndex || !fields.at( fidx ).defaultValueDefinition().isValid() || !fields.at( fidx ).defaultValueDefinition().applyOnUpdate() )
      continue;

    QgsExpression exp( fields.at( fidx ).defaultValueDefinition().expression() );
    exp.prepare( &mExpressionContext );

    // avoid cost of value update if expression doesn't contain the field which triggered the default values update
    if ( !exp.referencedColumns().contains( fieldName ) && !exp.referencedColumns().contains( QgsFeatureRequest::ALL_ATTRIBUTES ) )
      continue;

    const QVariant defaultValue = exp.evaluate( &mExpressionContext );
    const QVariant previousValue = mFeatureModel->data( mFeatureModel->index( fidx ), FeatureModel::AttributeValue );
    const bool success = mFeatureModel->setData( mFeatureModel->index( fidx ), defaultValue, FeatureModel::AttributeValue );
    const QVariant updatedValue = mFeatureModel->data( mFeatureModel->index( fidx ), FeatureModel::AttributeValue );
    if ( success && updatedValue != previousValue )
    {
      synchronizeFieldValue( fidx, updatedValue );
      if ( !updatedFields.contains( fidx ) )
      {
        updatedFields.append( fidx );
        updateDefaultValues( fidx, updatedFields );
      }
      updateVisibilityAndConstraints( fidx );
    }
  }

  updateEditorWidgetCodes( fieldName );
}

void AttributeFormModelBase::updateEditorWidgetCodes( const QString &fieldName )
{
  QMap<QStandardItem *, QString>::ConstIterator editorWidgetCodesIterator( mEditorWidgetCodes.constBegin() );
  for ( ; editorWidgetCodesIterator != mEditorWidgetCodes.constEnd(); editorWidgetCodesIterator++ )
  {
    QStandardItem *item = editorWidgetCodesIterator.key();
    if ( !item )
    {
      continue;
    }
    QString code = editorWidgetCodesIterator.value();
    bool needUpdate = false;

    if ( item->data( AttributeFormModel::ElementType ) == QStringLiteral( "qml" ) || item->data( AttributeFormModel::ElementType ) == QStringLiteral( "html" ) )
    {
      const thread_local QRegularExpression sRegEx( "expression\\.evaluate\\(\\s*\\\"(.*?[^\\\\])\\\"\\s*\\)", QRegularExpression::MultilineOption | QRegularExpression::DotMatchesEverythingOption );
      QRegularExpressionMatchIterator matchIt = sRegEx.globalMatch( code );
      while ( matchIt.hasNext() )
      {
        const QRegularExpressionMatch match = matchIt.next();
        QString expression = match.captured( 1 );
        expression = expression.replace( QStringLiteral( "\\\"" ), QStringLiteral( "\"" ) );

        QgsExpression exp( expression );
        exp.prepare( &mExpressionContext );
        if ( exp.referencedColumns().contains( fieldName ) || exp.referencedColumns().contains( QgsFeatureRequest::ALL_ATTRIBUTES ) )
        {
          needUpdate = true;
          break;
        }
      }

      if ( needUpdate )
      {
        QRegularExpressionMatch match = sRegEx.match( code );
        while ( match.hasMatch() )
        {
          QString expression = match.captured( 1 );
          expression = expression.replace( QStringLiteral( "\\\"" ), QStringLiteral( "\"" ) );

          QgsExpression exp = QgsExpression( expression );
          exp.prepare( &mExpressionContext );
          QVariant result = exp.evaluate( &mExpressionContext );

          QString resultString;
          switch ( static_cast<QMetaType::Type>( result.type() ) )
          {
            case QMetaType::Int:
            case QMetaType::UInt:
            case QMetaType::Double:
            case QMetaType::LongLong:
            case QMetaType::ULongLong:
              resultString = result.toString();
              break;
            case QMetaType::Bool:
              resultString = result.toBool() ? QStringLiteral( "true" ) : QStringLiteral( "false" );
              break;
            default:
              resultString = QStringLiteral( "'%1'" ).arg( result.toString() );
              break;
          }
          code = code.mid( 0, match.capturedStart( 0 ) ) + resultString + code.mid( match.capturedEnd( 0 ) );
          match = sRegEx.match( code );
        }
        item->setData( code, AttributeFormModel::EditorWidgetCode );
      }
    }
    else if ( item->data( AttributeFormModel::ElementType ) == QStringLiteral( "text" ) )
    {
      const thread_local QRegularExpression sRegEx( QStringLiteral( "\\[%(.*?)%\\]" ), QRegularExpression::MultilineOption | QRegularExpression::DotMatchesEverythingOption );
      QRegularExpressionMatchIterator matchIt = sRegEx.globalMatch( code );
      while ( matchIt.hasNext() )
      {
        const QRegularExpressionMatch match = matchIt.next();

        QgsExpression exp( match.captured( 1 ) );
        exp.prepare( &mExpressionContext );
        if ( exp.referencedColumns().contains( fieldName ) || exp.referencedColumns().contains( QgsFeatureRequest::ALL_ATTRIBUTES ) )
        {
          needUpdate = true;
          break;
        }
      }

      if ( needUpdate )
      {
        code = QgsExpression::replaceExpressionText( code, &mExpressionContext );
        item->setData( code, AttributeFormModel::EditorWidgetCode );
      }
    }
  }
}

void _checkChildrenValidity( QStandardItem *parent, bool &hardValidity, bool &softValidity )
{
  QStandardItem *item = parent->child( 0, 0 );
  while ( item )
  {
    const bool isVisible = item->data( AttributeFormModel::CurrentlyVisible ).toBool();
    if ( isVisible )
    {
      if ( !item->data( AttributeFormModel::ConstraintHardValid ).toBool() )
      {
        hardValidity = false;
        break;
      }
      if ( !item->data( AttributeFormModel::ConstraintSoftValid ).toBool() )
      {
        softValidity = false;
      }
    }

    if ( isVisible && item->hasChildren() )
    {
      _checkChildrenValidity( item, hardValidity, softValidity );
    }
    item = parent->child( item->row() + 1, 0 );
  }
};

void AttributeFormModelBase::updateVisibilityAndConstraints( int fieldIndex )
{
  QgsFields fields = mFeatureModel->feature().fields();
  mExpressionContext.setFields( fields );
  mExpressionContext.setFeature( mFeatureModel->feature() );

  bool visibilityChanged = false;
  for ( const VisibilityExpression &it : std::as_const( mVisibilityExpressions ) )
  {
    if ( fieldIndex == -1 || it.first.referencedAttributeIndexes( fields ).contains( fieldIndex ) )
    {
      QgsExpression exp = it.first;
      exp.prepare( &mExpressionContext );

      bool visible = exp.evaluate( &mExpressionContext ).toInt();
      QStandardItem *item = it.second;
      if ( item->data( AttributeFormModel::CurrentlyVisible ).toBool() != visible )
      {
        item->setData( visible, AttributeFormModel::CurrentlyVisible );
        visibilityChanged = true;
      }
    }
  }

  QMap<QStandardItem *, QgsFieldConstraints>::ConstIterator constraintIterator( mConstraints.constBegin() );
  QMap<int, bool> hardConstraintsCache;
  QMap<int, bool> softConstraintsCache;
  bool validityChanged = false;
  for ( ; constraintIterator != mConstraints.constEnd(); ++constraintIterator )
  {
    QStandardItem *item = constraintIterator.key();
    int fidx = item->data( AttributeFormModel::FieldIndex ).toInt();
    if ( fieldIndex != -1 && fidx != fieldIndex )
    {
      const QString fieldName = mLayer->fields().at( fieldIndex ).name();
      const QgsExpression expression = mLayer->fields().at( fieldIndex ).constraints().constraintExpression();
      if ( !expression.referencedColumns().contains( fieldName ) )
      {
        continue;
      }
    }

    if ( mFeatureModel->data( mFeatureModel->index( fidx ), FeatureModel::AttributeAllowEdit ) == true )
    {
      QStringList errors;

      QgsFeature feature = mFeatureModel->feature();
      QString defaultValueClause = mLayer->dataProvider()->defaultValueClause( fidx );
      QString attrValue = feature.attribute( fidx ).toString();

      // Providers will check for a literal "defaultValueClause" to autogenerate PKs.
      // For example, the gpkg provider will generate a fid if it is set to "Autogenerate".
      // On QField, if the user leaves the field empty, we will assume he wants to autogenerate it.
      // This makes sure, the NOT NULL constraint is skipped in this case.
      if ( attrValue.isEmpty() && !defaultValueClause.isEmpty() )
      {
        feature.setAttribute( fidx, defaultValueClause );
      }

      bool hardConstraintSatisfied = false;
      if ( !hardConstraintsCache.contains( fidx ) )
      {
        hardConstraintSatisfied = QgsVectorLayerUtils::validateAttribute( mLayer, feature, fidx, errors, QgsFieldConstraints::ConstraintStrengthHard );
        hardConstraintsCache[fidx] = hardConstraintSatisfied;
      }
      else
      {
        hardConstraintSatisfied = hardConstraintsCache.value( fidx );
      }
      if ( hardConstraintSatisfied != item->data( AttributeFormModel::ConstraintHardValid ).toBool() )
      {
        item->setData( hardConstraintSatisfied, AttributeFormModel::ConstraintHardValid );
        validityChanged = true;
      }

      bool softConstraintSatisfied = false;
      if ( !softConstraintsCache.contains( fidx ) )
      {
        softConstraintSatisfied = QgsVectorLayerUtils::validateAttribute( mLayer, mFeatureModel->feature(), fidx, errors, QgsFieldConstraints::ConstraintStrengthSoft );
        softConstraintsCache[fidx] = softConstraintSatisfied;
      }
      else
      {
        softConstraintSatisfied = softConstraintsCache.value( fidx );
      }
      if ( softConstraintSatisfied != item->data( AttributeFormModel::ConstraintSoftValid ).toBool() )
      {
        item->setData( softConstraintSatisfied, AttributeFormModel::ConstraintSoftValid );
        validityChanged = true;
      }
    }
    else
    {
      item->setData( true, AttributeFormModel::ConstraintHardValid );
      item->setData( true, AttributeFormModel::ConstraintSoftValid );
    }
  }

  // reset contrainsts status of containers
  if ( validityChanged || visibilityChanged )
  {
    bool allConstraintsHardValid = true;
    bool allConstraintsSoftValid = true;

    if ( mHasTabs )
    {
      QStandardItem *root = invisibleRootItem();
      for ( int i = 0; i < root->rowCount(); i++ )
      {
        bool hardValidity = true;
        bool softValidity = true;

        QStandardItem *tab = root->child( i, 0 );
        _checkChildrenValidity( tab, hardValidity, softValidity );
        if ( !hardValidity )
        {
          allConstraintsHardValid = false;
        }
        if ( !softValidity )
        {
          allConstraintsSoftValid = false;
        }
        tab->setData( hardValidity, AttributeFormModel::ConstraintHardValid );
        tab->setData( softValidity, AttributeFormModel::ConstraintSoftValid );
      }
    }
    else
    {
      bool hardValidity = true;
      bool softValidity = true;
      QStandardItem *tab = invisibleRootItem();
      _checkChildrenValidity( tab, hardValidity, softValidity );

      if ( !hardValidity )
      {
        allConstraintsHardValid = false;
      }
      if ( !softValidity )
      {
        allConstraintsSoftValid = false;
      }
    }

    setConstraintsHardValid( allConstraintsHardValid );
    setConstraintsSoftValid( allConstraintsSoftValid );
  }
}

bool AttributeFormModelBase::constraintsHardValid() const
{
  return mConstraintsHardValid;
}

bool AttributeFormModelBase::constraintsSoftValid() const
{
  return mConstraintsSoftValid;
}

QVariant AttributeFormModelBase::attribute( const QString &name )
{
  if ( !mLayer )
    return QVariant();

  int idx = mLayer->fields().indexOf( name );
  return mFeatureModel->data( mFeatureModel->index( idx ), FeatureModel::AttributeValue );
}

void AttributeFormModelBase::setConstraintsHardValid( bool constraintsHardValid )
{
  if ( constraintsHardValid == mConstraintsHardValid )
    return;

  mConstraintsHardValid = constraintsHardValid;
  emit constraintsHardValidChanged();
}

void AttributeFormModelBase::setConstraintsSoftValid( bool constraintsSoftValid )
{
  if ( constraintsSoftValid == mConstraintsSoftValid )
    return;

  mConstraintsSoftValid = constraintsSoftValid;
  emit constraintsSoftValidChanged();
}

QgsEditorWidgetSetup AttributeFormModelBase::findBest( const int fieldIndex )
{
  QgsFields fields = mLayer->fields();

  //make the default one
  QgsEditorWidgetSetup setup = QgsEditorWidgetSetup( QStringLiteral( "TextEdit" ), QVariantMap() );

  if ( fieldIndex >= 0 && fieldIndex < fields.count() )
  {
    //when field has a configured setup, take it
    setup = mLayer->editorWidgetSetup( fieldIndex );
    if ( !setup.isNull() )
      return setup;

    //when it's a provider field with default value clause, take Textedit
    if ( fields.fieldOrigin( fieldIndex ) == QgsFields::OriginProvider )
    {
      int providerOrigin = fields.fieldOriginIndex( fieldIndex );
      if ( !mLayer->dataProvider()->defaultValueClause( providerOrigin ).isEmpty() )
        return setup;
    }

    //find the best one
    const QgsField field = fields.at( fieldIndex );
    //on a boolean type take "CheckBox"
    if ( field.type() == QVariant::Bool )
      setup = QgsEditorWidgetSetup( QStringLiteral( "CheckBox" ), QVariantMap() );
    //on a date or time type take "DateTime"
    if ( field.isDateOrTime() )
    {
      QVariantMap config;
      config.insert( QStringLiteral( "field_format" ), QgsDateTimeFieldFormatter::defaultFormat( field.type() ) );
      config.insert( QStringLiteral( "display_format" ), QgsDateTimeFieldFormatter::defaultFormat( field.type() ) );
      config.insert( QStringLiteral( "calendar_popup" ), true );
      config.insert( QStringLiteral( "allow_null" ), true );
      setup = QgsEditorWidgetSetup( QStringLiteral( "DateTime" ), config );
    }
    //on numeric types take "Range"
    if ( field.type() == QVariant::Int || field.type() == QVariant::Double || field.isNumeric() )
      setup = QgsEditorWidgetSetup( QStringLiteral( "Range" ), QVariantMap() );
    //if it's a foreign key configured in a relation take "RelationReference"
    if ( !mLayer->referencingRelations( fieldIndex ).isEmpty() )
    {
      QgsRelation relation = mLayer->referencingRelations( fieldIndex )[0];
      QVariantMap config;
      config.insert( QStringLiteral( "Relation" ), relation.id() );
      config.insert( QStringLiteral( "AllowAddFeatures" ), false );
      config.insert( QStringLiteral( "ShowOpenFormButton" ), true );
      setup = QgsEditorWidgetSetup( QStringLiteral( "RelationReference" ), config );
    }
  }

  return setup;
}

bool AttributeFormModelBase::hasTabs() const
{
  return mHasTabs;
}

void AttributeFormModelBase::setHasTabs( bool hasTabs )
{
  if ( hasTabs == mHasTabs )
    return;

  mHasTabs = hasTabs;
  emit hasTabsChanged();
}

bool AttributeFormModelBase::save()
{
  return mFeatureModel->save();
}

bool AttributeFormModelBase::create()
{
  return mFeatureModel->create();
}

bool AttributeFormModelBase::deleteFeature()
{
  return mFeatureModel->deleteFeature();
}
