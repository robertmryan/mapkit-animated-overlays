//
//  ViewController.m
//  MapKit Animated Overlays
//
//  Created by Robert Ryan on 4/29/13.
//  Copyright (c) 2013 Robert Ryan. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>

@interface ViewController () <MKMapViewDelegate>

@property (nonatomic, strong) NSMutableArray *coordinates;
@property (nonatomic, weak) MKPolyline *polyLine;                  // used during the drawing of the polyline, but discarded once the MKPolygon is added
@property (nonatomic, weak) MKPointAnnotation *previousAnnotation; // if you're using other annotations, you might want to use a custom annotation type here
@property (nonatomic) BOOL isDrawingPolygon;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
}

- (IBAction)didTouchUpInsideDrawButton:(id)sender
{
    if (!self.isDrawingPolygon)
    {
        // We're starting the drawing of our polyline/polygon, so
        // let's initialize everything
        
        self.isDrawingPolygon = YES;
        
        self.coordinates = [NSMutableArray array];
        
        // turn off map interaction so touches can fall through to
        // here
        
        self.mapView.userInteractionEnabled = NO;
        
        // change our "draw overlay" button to "done"
        
        [self.drawOverlayButton setTitle:@"Done"];
    }
    else
    {
        // We're finishing the drawing of our polyline, so let's
        // clean up, remove polyline, and add polygon
        
        self.isDrawingPolygon = NO;
        
        // let's restore map interaction
        
        self.mapView.userInteractionEnabled = YES;
        
        // and, if we drew more than two points, let's draw our polygon
        
        NSInteger numberOfPoints = [self.coordinates count];
        
        if (numberOfPoints > 2)
        {
            CLLocationCoordinate2D points[numberOfPoints];
            for (NSInteger i = 0; i < numberOfPoints; i++)
                points[i] = [self.coordinates[i] MKCoordinateValue];
            [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
        }
        
        // and if we had a polyline, let's remove it
        
        if (self.polyLine)
            [self.mapView removeOverlay:self.polyLine];
        
        // change our "draw overlay" button to "done"
        
        [self.drawOverlayButton setTitle:@"Draw overlay"];
        
        // remove our old point annotation
        
        if (self.previousAnnotation)
            [self.mapView removeAnnotation:self.previousAnnotation];
    }
}

- (void)addCoordinate:(CLLocationCoordinate2D)coordinate replaceLastObject:(BOOL)replaceLast
{
    if (replaceLast && [self.coordinates count] > 0)
        [self.coordinates removeLastObject];
    
    [self.coordinates addObject:[NSValue valueWithMKCoordinate:coordinate]];
    
    NSInteger numberOfPoints = [self.coordinates count];
    
    // if we have more than one point, then we're drawing a line segment
    
    if (numberOfPoints > 1)
    {
        MKPolyline *oldPolyLine = self.polyLine;
        CLLocationCoordinate2D points[numberOfPoints];
        for (NSInteger i = 0; i < numberOfPoints; i++)
            points[i] = [self.coordinates[i] MKCoordinateValue];
        MKPolyline *newPolyLine = [MKPolyline polylineWithCoordinates:points count:numberOfPoints];
        [self.mapView addOverlay:newPolyLine];
        
        self.polyLine = newPolyLine;
        
        // note, remove old polyline _after_ adding new one, to avoid flickering effect
        
        if (oldPolyLine)
            [self.mapView removeOverlay:oldPolyLine];
        
    }
    
    // let's draw an annotation where we tapped
    
    MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
    newAnnotation.coordinate = coordinate;
    [self.mapView addAnnotation:newAnnotation];
    
    // if we had an annotation for the previous location, remove it
    
    if (self.previousAnnotation)
        [self.mapView removeAnnotation:self.previousAnnotation];
    
    // and save this annotation for future reference
    
    self.previousAnnotation = newAnnotation;
}

- (BOOL)isClosingPolygonWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    if ([self.coordinates count] > 2)
    {
        CLLocationCoordinate2D startCoordinate = [self.coordinates[0] MKCoordinateValue];
        CGPoint start = [self.mapView convertCoordinate:startCoordinate
                                          toPointToView:self.mapView];
        CGPoint end = [self.mapView convertCoordinate:coordinate
                                        toPointToView:self.mapView];
        CGFloat xDiff = end.x - start.x;
        CGFloat yDiff = end.y - start.y;
        CGFloat distance = sqrtf(xDiff * xDiff + yDiff * yDiff);
        if (distance < 30.0)
        {
            [self.coordinates removeLastObject];
            return YES;
        }
    }
    
    return NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.isDrawingPolygon)
        return;
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
    
    [self addCoordinate:coordinate replaceLastObject:NO];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.isDrawingPolygon)
        return;
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
    
    [self addCoordinate:coordinate replaceLastObject:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.isDrawingPolygon)
        return;
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
    
    [self addCoordinate:coordinate replaceLastObject:YES];
    
    // detect if this coordinate is close enough to starting
    // coordinate to qualify as closing the polygon
    
    if ([self isClosingPolygonWithCoordinate:coordinate])
        [self didTouchUpInsideDrawButton:nil];
}

#pragma mark - MKMapViewDelegate

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    MKOverlayPathView *overlayPathView;
    
    if ([overlay isKindOfClass:[MKPolygon class]])
    {
        overlayPathView = [[MKPolygonView alloc] initWithPolygon:(MKPolygon*)overlay];
        
        overlayPathView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        overlayPathView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayPathView.lineWidth = 3;
        
        return overlayPathView;
    }
    
    else if ([overlay isKindOfClass:[MKPolyline class]])
    {
        overlayPathView = [[MKPolylineView alloc] initWithPolyline:(MKPolyline *)overlay];
        
        overlayPathView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayPathView.lineWidth = 3;
        
        return overlayPathView;
    }
    
    return nil;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    static NSString * const annotationIdentifier = @"CustomAnnotation";
    
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
    
    if (annotationView)
    {
        annotationView.annotation = annotation;
    }
    else
    {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationIdentifier];
        annotationView.image = [UIImage imageNamed:@"annotation.png"];
        annotationView.alpha = 0.5;
    }
    
    annotationView.canShowCallout = NO;
    
    return annotationView;
}

@end
