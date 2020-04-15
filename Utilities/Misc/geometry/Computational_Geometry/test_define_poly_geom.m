close all
clear all
clc

global IAXIS JAXIS KAXIS NOD1 NOD2 NOD3
IAXIS=1; JAXIS=2; KAXIS=3;
NOD1 =1; NOD2 =2; NOD3 =3;

NORM_EPS=10^-10;
TWO_EPSILON_EPS=1.E-13;

% Input Data:
N_VERTS      = 6;
N_POLY_VERTS = N_VERTS;
VERTS   = [-1.0, -1.0, 1.0, .0, -1.0, 1.5, 0.0, 0.0, 1.5, 1.0, 0.0, 2.0, 1.0, 1.0, 2.0, -1.0, 1.0, 1.0]; 
POLY    = [ 1, 2, 3, 4, 5, 6];
EXTRUDE = -0.6;


%% Start of routine: arguments N_VERTS,N_POLY_VERTS,VERTS,POLY,EXTRUDE

% Do some tests in POLY, Repeated vertex, zero index, etc.:
if(N_POLY_VERTS > N_VERTS)
    disp(['Error : Number of POLY indexes ' num2str(N_POLY_VERTS) ' > N_VERTS=' num2str(N_VERTS) '.'])
    return
end
for J=1:N_POLY_VERTS
    if(POLY(J)==0)
        disp(['Error : Zero vertex index in location ' num2str(J) ' of Polyline.'])
        return
    end
    for I=J+1:N_POLY_VERTS
        if(POLY(I)==POLY(J)) 
            disp(['Error : Repeated vertex ' num2str(POLY(I)) ' in Polyline.'])
            return
        end
        DV=VERTS(3*POLY(I)-2:3*POLY(I))-VERTS(3*POLY(J)-2:3*POLY(J));
        if(norm(DV) < NORM_EPS)
            disp(['Error : Vertices ' num2str(POLY(I)) ' and ' num2str(POLY(J)) ...
                  ' have same position : ' num2str(VERTS(3*POLY(I)-2:3*POLY(I)))])
            return
        end
    end
end
           

% Define PVERTS:
PVERTS = zeros(1,6*N_POLY_VERTS);
for I=1:N_POLY_VERTS
    PVERTS(3*I-2:3*I) = VERTS(3*POLY(I)-2:3*POLY(I));
end
PVERTS(3*(N_POLY_VERTS+1)-2:3*(N_POLY_VERTS+1)) = PVERTS(1:3);
% Define average normal:
XYZCEN = zeros(1,3);
for I=1:N_POLY_VERTS
   XYZCEN(IAXIS:KAXIS) = XYZCEN(IAXIS:KAXIS) + PVERTS(3*I-2:3*I);    
end
XYZCEN = XYZCEN/N_POLY_VERTS;

NVEC = zeros(1,3);
for I=1:N_POLY_VERTS
   V1 = PVERTS(3*I-2:3*I    ) - XYZCEN(IAXIS:KAXIS);
   V2 = PVERTS(3*I+1:3*(I+1)) - XYZCEN(IAXIS:KAXIS);
   N  = cross(V1,V2);
   if(norm(N) > TWO_EPSILON_EPS); N = N/norm(N); end
   NVEC(IAXIS:KAXIS) = NVEC(IAXIS:KAXIS) + N(IAXIS:KAXIS);
end
if(norm(NVEC) > TWO_EPSILON_EPS); NVEC=NVEC/norm(NVEC); end

IS_CONVEX= true;
NODE_FLG = ones(1,N_POLY_VERTS+1);
for I=1:N_POLY_VERTS
   IM1 = I - 1;
   if (I==1); IM1=N_POLY_VERTS; end
   IP1 = I + 1;
   if (I==N_POLY_VERTS); IP1=1; end
   V1 = PVERTS(3*I-2:3*I    ) - PVERTS(3*IM1-2:3*IM1    ); V1=V1/norm(V1);
   V2 = PVERTS(3*IP1-2:3*IP1) - PVERTS(3*I-2:3*I        ); V2=V2/norm(V2);
   V1XV2  = cross(V1,V2);
   SINANG = norm(V1XV2);
   if ( dot(NVEC,V1XV2)  <-NORM_EPS ); IS_CONVEX  = false; end
   if ( SINANG           < NORM_EPS ); NODE_FLG(I)= 0; end % Vertex located in line joining neighbors.
end

NVERTS2 = sum(NODE_FLG(1:N_POLY_VERTS));
if (NVERTS2 < 3) 
    disp('Error in POLY geometry : Not enough valid vertices on the polygon.')
end    
NEDGES = NVERTS2;
PVERTS2=zeros(1,N_POLY_VERTS);
COUNT = 0;
for I=1:N_POLY_VERTS
   if(NODE_FLG(I)==0); continue; end
   COUNT= COUNT + 1;
   PVERTS2(3*COUNT-2:3*COUNT) = PVERTS(3*I-2:3*I);
   VERT_LIST(COUNT) = COUNT;
end
PVERTS(1:3*NVERTS2)  = PVERTS2(1:3*NVERTS2);
VERT_LIST(NVERTS2+1) = VERT_LIST(1);
NODE_EXISTS(1:NVERTS2+1) = true;

% Now do the Ear clip:
N_FACES  = 0;
if(IS_CONVEX) % Convex POLY.
   VERT_START = VERT_LIST(1);
   
   for I = 1:NVERTS2
      IP1 = I+1;
      if (I==NVERTS2); IP1=1; end
      if (I==VERT_START || IP1==VERT_START); continue; end
      N_FACES = N_FACES + 1;
      FACES(3*N_FACES-2) = VERT_LIST(VERT_START);
      FACES(3*N_FACES-1) = VERT_LIST(I);
      FACES(3*N_FACES  ) = VERT_LIST(IP1);
   end
else % Simple polygon, ear clipping.
    disp('Non convex polygon')
    NLIST = NVERTS2;
    COUNT_OUT = 0;
    while(NLIST>=3) % OUTER LOOP      
         COUNT_OUT = COUNT_OUT + 1;
         if(COUNT_OUT > NVERTS2^4) 
             disp('Error: Could not EAR clip polygon.')
             break
         end
         
         IVERT=1;
         HAVE_TRIANGLE=false;
         EXIT_OUTER=false;
         while(IVERT<=NLIST) % INNER LOOP
            IVM1 = IVERT-1; IV=IVERT; IVP1=IVERT+1;
            if (IVERT==1); IVM1=NLIST; end
            V0 = VERT_LIST(IVM1);
            V1 = VERT_LIST(IV  );
            V2 = VERT_LIST(IVP1);
            if(~NODE_EXISTS(IVP1)); break; end
            DV1(IAXIS:KAXIS) = PVERTS(3*V1-2:3*V1)-PVERTS(3*V0-2:3*V0); 
            if (norm(DV1)>TWO_EPSILON_EPS)
                DV1=DV1/norm(DV1);
            else
                continue
            end
            DV2(IAXIS:KAXIS) = PVERTS(3*V2-2:3*V2)-PVERTS(3*V1-2:3*V1); 
            if (norm(DV2)>TWO_EPSILON_EPS)
                DV2=DV2/norm(DV2);
            else
                continue
            end
            if(NLIST==3 || dot(NVEC,cross(DV1,DV2))>NORM_EPS)
                 N_FACES = N_FACES + 1;
                 FACES(3*N_FACES-2) = V0;
                 FACES(3*N_FACES-1) = V1;
                 FACES(3*N_FACES  ) = V2;
                 if (NLIST == 3); EXIT_OUTER=true; break; end
                 NODE_EXISTS(IVERT) =false; 
                 if(IVERT==1); NODE_EXISTS(NLIST+1)=false; end
                 HAVE_TRIANGLE =true;
                 IVERT = IVERT + 2;
            else
                 IVERT = IVERT + 1;
            end
         end
         if(EXIT_OUTER); break; end
         
         NLIST_OLD = NLIST;
         NLIST     = 0;
         for I = 1:NLIST_OLD
             if(NODE_EXISTS(I))
                 NLIST = NLIST + 1;
                 VERT_LIST(NLIST) = VERT_LIST(I);
             end
         end
         VERT_LIST(NLIST+1) = VERT_LIST(1);
         NODE_EXISTS(1:NLIST+1) = true;
              
         % Test for nodes connecting parallel edges, if found drop them:
         VERT_DROPPED=false;
         for I=1:NLIST
            IVM1 = I-1; IV=I; IVP1=I+1;
            if (I==1); IVM1=NLIST; end
            V0 = VERT_LIST(IVM1);
            V1 = VERT_LIST(IV  );
            V2 = VERT_LIST(IVP1);
            DV1(IAXIS:KAXIS) = PVERTS(3*V1-2:3*V1)-PVERTS(3*V0-2:3*V0);
            if (norm(DV1)>TWO_EPSILON_EPS)
                DV1=DV1/norm(DV1);
            else
                continue
            end
            DV2(IAXIS:KAXIS) = PVERTS(3*V2-2:3*V2)-PVERTS(3*V1-2:3*V1);
            if (norm(DV2)>TWO_EPSILON_EPS)
                DV2=DV2/norm(DV2);
            else
                continue
            end
            if(abs(dot(NVEC,cross(DV1,DV2)))<NORM_EPS)
               VERT_DROPPED=true; NODE_EXISTS(I)=false;
               if (N_FACES < (NVERTS2-2)) 
                  N_FACES = N_FACES + 1;
                  FACES(IFACE  ) = V0;
                  FACES(IFACE+1) = V1;
                  FACES(IFACE+2) = V2;
               end
               if (NLIST == 3); EXIT_OUTER=true; break; end
            end
         end
         if(EXIT_OUTER); break; end
         
         if(VERT_DROPPED)
             % Repeat List generation:
             NLIST_OLD = NLIST;
             NLIST = 0;
             for I = 1:NLIST_OLD
                 if(NODE_EXISTS(I))
                     NLIST = NLIST + 1;
                     VERT_LIST(NLIST) = VERT_LIST(I);
                 end
             end
             VERT_LIST(NLIST+1) = VERT_LIST(1);
             NODE_EXISTS(1:NLIST+1) = true;
         end
     
    end
end
% Add top faces and Revert lo faces normal:
START_FACES_HI = N_FACES;
FCOUNT=N_FACES;
for IFACE=1:N_FACES
    FACES(3*(FCOUNT+IFACE)-2:3*(FCOUNT+IFACE))=FACES(3*IFACE-2:3*IFACE)+NVERTS2;
    IDUM=FACES(3*IFACE-1);
    FACES(3*IFACE-1)=FACES(3*IFACE);
    FACES(3*IFACE)=IDUM;
end
N_FACES = 2*N_FACES;

% Now replicate Vertices at a distance EXTRUDE in the normal direction.
N_VERTS = 2*NVERTS2;
VERTS   = zeros(1,3*N_VERTS);
VERTS(1:3*NVERTS2) = PVERTS(1:3*NVERTS2);
for I=1:NVERTS2
    VERTS(3*(I+NVERTS2)-2:3*(I+NVERTS2)) = ...
    PVERTS(3*I-2:3*I) + EXTRUDE*NVEC(IAXIS:KAXIS);
end

% Add side faces:
START_FACES_SIDE=N_FACES;
for IVERT=1:NVERTS2
    I1 = IVERT; 
    I2 = IVERT +       1;
    I3 = IVERT + NVERTS2;
    I4 = IVERT + NVERTS2 + 1; 
    if(IVERT==NVERTS2)
        I2 = 1; 
        I4 = 1 + NVERTS2;
    end
    N_FACES = N_FACES + 1;
    FACES(3*N_FACES-2:3*N_FACES) = [I1 I2 I4];
    N_FACES = N_FACES + 1;
    FACES(3*N_FACES-2:3*N_FACES) = [I1 I4 I3];
end

% Revert Faces order if EXTRUDE -ve:
if(EXTRUDE < 0)
    for IFACE=1:N_FACES
        IDUM=FACES(3*IFACE-1);
        FACES(3*IFACE-1)=FACES(3*IFACE);
        FACES(3*IFACE)=IDUM;
    end
end

%% End of routine : Output N_VERTS,VERTS,N_FACES,FACES,START_FACES_LO,START_FACES_HI,START_FACES_SIDE
%%

% Plot:
a=0.2;
figure
hold on
xlabel('X')
ylabel('Y')
zlabel('Z')
axis equal; view([45 45])
box on
for IFACE=1:N_FACES
    X(1,IAXIS:KAXIS) = VERTS(3*FACES(3*IFACE-2)-2:3*FACES(3*IFACE-2));
    X(2,IAXIS:KAXIS) = VERTS(3*FACES(3*IFACE-1)-2:3*FACES(3*IFACE-1));
    X(3,IAXIS:KAXIS) = VERTS(3*FACES(3*IFACE  )-2:3*FACES(3*IFACE  ));
    XYZCEN = 1/3*(X(1,IAXIS:KAXIS)+X(2,IAXIS:KAXIS)+X(3,IAXIS:KAXIS));
    N = cross(X(2,IAXIS:KAXIS)-X(1,IAXIS:KAXIS),X(3,IAXIS:KAXIS)-X(1,IAXIS:KAXIS));
    N = N/norm(N);
    [hp]=patch(X(:,IAXIS),X(:,JAXIS),X(:,KAXIS),'b');
    plot3([XYZCEN(IAXIS) XYZCEN(IAXIS)+a*N(IAXIS)],...
          [XYZCEN(JAXIS) XYZCEN(JAXIS)+a*N(JAXIS)],...
          [XYZCEN(KAXIS) XYZCEN(KAXIS)+a*N(KAXIS)],'-r')

    set(hp,'FaceAlpha',0.3) 
end
for I=1:2*NVERTS2
    plot3(VERTS(3*I-2),VERTS(3*I-1),VERTS(3*I),'-ok')
    text(VERTS(3*I-2),VERTS(3*I-1),VERTS(3*I),num2str(I),'FontSize',14)
end




